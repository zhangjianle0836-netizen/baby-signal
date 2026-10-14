#!/bin/bash
set -euo pipefail
task_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$task_root"
mkdir -p .build
lock_dir="$task_root/.build/verification.lock"
if ! mkdir "$lock_dir" 2>/dev/null; then
  printf '%s\n' '已有验证锁，请检查 .build/verification.lock/pid 的进程是否仍在运行。' >&2
  exit 1
fi
trap 'rm -f "$lock_dir/pid"; rmdir "$lock_dir"' EXIT
printf '%s\n' "$$" > "$lock_dir/pid"
if command -v rg >/dev/null 2>&1; then
  running_commands="$(ps -axo command | rg '(xcodebuild|swift-frontend|swift build|swift test)' | rg -F "$task_root" || true)"
else
  # Stock macOS includes grep; keep the process guard without requiring Homebrew.
  running_commands="$(ps -axo command | grep -E '(xcodebuild|swift-frontend|swift build|swift test)' | grep -F "$task_root" || true)"
fi
if [[ -n "$running_commands" ]]; then
  printf '%s\n' '检测到本项目已有编译或验证进程，请等待结束：' "$running_commands" >&2
  exit 1
fi
case "${1:-all}" in
  tests|all)
    xcrun swiftc BabySignal/Core/L10n.swift BabySignal/Core/CryEventGate.swift BabySignal/Core/SignalEvent.swift BabySignal/Core/MonitoringRecovery.swift BabySignal/Core/MonitoringActivityState.swift \
      BabySignal/Services/EventRepository.swift Tests/main.swift -o .build/core-tests
    .build/core-tests
    ;;
  build) ;;
  device)
    if [[ ! "${2:-}" =~ ^[A-Za-z0-9-]+$ ]]; then
      printf '%s\n' 'device 模式需要设备 UDID。' >&2
      exit 2
    fi
    ;;
  *) printf '%s\n' '用法: scripts/verify.sh [tests|build|all|device UDID]' >&2; exit 2 ;;
esac
if [[ "${1:-all}" == device ]]; then
  xcodebuild -project BabySignal.xcodeproj -scheme BabySignal -configuration Debug \
    -destination "platform=iOS,id=$2" -derivedDataPath .build/DerivedData \
    -jobs 2 -allowProvisioningUpdates -allowProvisioningDeviceRegistration build
elif [[ "${1:-all}" != tests ]]; then
  xcodebuild -project BabySignal.xcodeproj -scheme BabySignal -configuration Debug \
    -destination 'generic/platform=iOS' -derivedDataPath .build/DerivedData \
    -jobs 2 CODE_SIGNING_ALLOWED=NO build
fi
