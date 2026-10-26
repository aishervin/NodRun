import { NativeModules, Platform } from "react-native"

type TermuxBridgeNative = {
  runCommand(command: string): Promise<boolean>
  openTermux(): Promise<boolean>
}

const native = NativeModules.TermuxBridge as TermuxBridgeNative | undefined

export function isTermuxBridgeAvailable(): boolean {
  return Platform.OS === "android" && Boolean(native?.runCommand)
}

export async function runTermuxCommand(command: string): Promise<void> {
  if (!isTermuxBridgeAvailable() || !native) {
    throw new Error("The NodRun Termux bridge is unavailable. Install the latest NodRun Android build.")
  }
  await native.runCommand(command)
}

export async function openTermux(): Promise<void> {
  if (!native?.openTermux) throw new Error("Termux launcher is unavailable in this build.")
  await native.openTermux()
}

export function managerCommand(action: "install" | "repair" | "start" | "stop" | "status" | "logs"): string {
  const script = "https://raw.githubusercontent.com/aishervin/NodRun/main/scripts/termux-opencode-manager.sh"
  return [
    'mkdir -p "$HOME/.local/bin" "$HOME/.local/state/nodrun-opencode"',
    'curl -fsSL "' + script + '" -o "$HOME/.local/bin/nodrun-opencode-manager"',
    'chmod 700 "$HOME/.local/bin/nodrun-opencode-manager"',
    'bash "$HOME/.local/bin/nodrun-opencode-manager" ' + action,
  ].join(" && ")
}
