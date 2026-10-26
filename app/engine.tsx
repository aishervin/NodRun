import { useCallback, useEffect, useState } from "react"
import { ActivityIndicator, Alert, ScrollView, StyleSheet, Text, TouchableOpacity, View, useColorScheme } from "react-native"
import { Stack, router } from "expo-router"
import { Ionicons } from "@expo/vector-icons"
import { useConnections } from "../src/stores/connections"
import { isTermuxBridgeAvailable, managerCommand, openTermux, runTermuxCommand } from "../src/lib/termux-bridge"

const ENGINE_URL = "http://127.0.0.1:4096"

type EngineStatus = "checking" | "online" | "offline" | "unsupported"

export default function EngineScreen() {
  const isDark = useColorScheme() === "dark"
  const [status, setStatus] = useState<EngineStatus>(isTermuxBridgeAvailable() ? "checking" : "unsupported")
  const [busy, setBusy] = useState<string | null>(null)
  const [message, setMessage] = useState("Checking the local OpenCode API…")
  const { connections, addConnection, setActiveConnection } = useConnections()

  const checkStatus = useCallback(async () => {
    try {
      const response = await fetch(ENGINE_URL + "/global/health", { method: "GET" })
      if (!response.ok) throw new Error("API returned HTTP " + response.status)
      setStatus("online")
      setMessage("OpenCode is running locally and ready to use.")
    } catch {
      setStatus("offline")
      setMessage("OpenCode is not responding yet. Install it or start the local engine.")
    }
  }, [])

  useEffect(() => {
    if (isTermuxBridgeAvailable()) void checkStatus()
  }, [checkStatus])

  const perform = async (action: "install" | "repair" | "start" | "stop" | "status" | "logs") => {
    setBusy(action)
    setMessage(action === "install" || action === "repair" ? "Installing OpenCode in Termux. This can take several minutes…" : "Sending command to Termux…")
    try {
      await runTermuxCommand(managerCommand(action))
      if (action === "stop") {
        setStatus("offline")
        setMessage("Stop command sent. The engine may take a moment to exit.")
        return
      }
      if (action === "logs") {
        await openTermux()
        setMessage("Termux opened. The manager output and server log are available there.")
        return
      }
      setMessage("Command sent. Waiting for the OpenCode API…")
      for (let i = 0; i < 25; i++) {
        await new Promise(resolve => setTimeout(resolve, 1000))
        try {
          const response = await fetch(ENGINE_URL + "/global/health")
          if (response.ok) {
            setStatus("online")
            setMessage("OpenCode is online. Connecting NodRun to the local engine…")
            const existing = connections.find(c => c.url.replace(/\/$/, "") === ENGINE_URL)
            if (existing) {
              await setActiveConnection(existing.id)
            } else {
              await addConnection({ name: "OpenCode on this phone", type: "local", url: ENGINE_URL, username: "opencode" })
              const created = useConnections.getState().connections.find(c => c.url.replace(/\/$/, "") === ENGINE_URL)
              if (created) await setActiveConnection(created.id)
            }
            setMessage("Connected. Open Sessions to start coding.")
            return
          }
        } catch { /* wait for server startup */ }
      }
      await checkStatus()
      setMessage("The command was sent, but the API did not become ready. Open Logs for details.")
    } catch (error) {
      const text = error instanceof Error ? error.message : String(error)
      setMessage(text)
      Alert.alert("Termux bridge unavailable", text + "\n\nOpen Termux once, enable Allow external apps in Settings, then retry.")
    } finally {
      setBusy(null)
    }
  }

  const card = isDark ? styles.cardDark : styles.card
  const text = isDark ? styles.textDark : styles.text
  const muted = isDark ? styles.mutedDark : styles.muted

  return (
    <View style={[styles.screen, isDark && styles.screenDark]}>
      <Stack.Screen options={{ title: "Local OpenCode Engine", headerBackTitle: "Back" }} />
      <ScrollView contentContainerStyle={styles.content}>
        <View style={[styles.hero, isDark && styles.heroDark]}>
          <View style={[styles.iconCircle, status === "online" && styles.iconOnline]}>
            <Ionicons name="hardware-chip-outline" size={30} color={status === "online" ? "#16a34a" : isDark ? "#fff" : "#111"} />
          </View>
          <Text style={[styles.title, text]}>Run OpenCode on this phone</Text>
          <Text style={[styles.subtitle, muted]}>NodRun manages the local engine in Termux. After the one-time permission setup, install, start and stop it from this screen—no terminal typing needed.</Text>
          <View style={styles.statusRow}>
            {status === "checking" && <ActivityIndicator size="small" />}
            <View style={[styles.dot, status === "online" ? styles.dotOnline : status === "offline" ? styles.dotOffline : styles.dotUnknown]} />
            <Text style={[styles.statusText, text]}>{status === "online" ? "Engine online" : status === "offline" ? "Engine stopped / not installed" : status === "unsupported" ? "Native bridge unavailable" : "Checking status"}</Text>
          </View>
          <Text style={[styles.message, muted]}>{message}</Text>
          <Text style={[styles.url, text]}>{ENGINE_URL}</Text>
        </View>

        {!isTermuxBridgeAvailable() ? (
          <View style={[styles.notice, card]}>
            <Text style={[styles.noticeTitle, text]}>Update required</Text>
            <Text style={muted}>This feature requires the NodRun Android APK built with the Termux bridge. A JavaScript-only update cannot invoke Termux commands.</Text>
          </View>
        ) : (
          <>
            <Text style={[styles.sectionTitle, text]}>Engine controls</Text>
            <TouchableOpacity disabled={!!busy} style={[styles.action, styles.primary]} onPress={() => void perform("install")}>
              {busy === "install" ? <ActivityIndicator color="#fff" /> : <Ionicons name="download-outline" size={20} color="#fff" />}
              <View style={styles.actionText}><Text style={styles.primaryLabel}>Install / Repair OpenCode</Text><Text style={styles.primaryHint}>Installs the Termux aarch64 build and starts the API</Text></View>
            </TouchableOpacity>
            <View style={styles.actionRow}>
              <TouchableOpacity disabled={!!busy} style={[styles.action, card, styles.half]} onPress={() => void perform("start")}>
                <Ionicons name="play-circle-outline" size={22} color={isDark ? "#fff" : "#111"} /><Text style={[styles.actionLabel, text]}>Start</Text>
              </TouchableOpacity>
              <TouchableOpacity disabled={!!busy} style={[styles.action, card, styles.half]} onPress={() => void perform("stop")}>
                <Ionicons name="stop-circle-outline" size={22} color={isDark ? "#fff" : "#111"} /><Text style={[styles.actionLabel, text]}>Stop</Text>
              </TouchableOpacity>
            </View>
            <View style={styles.actionRow}>
              <TouchableOpacity disabled={!!busy} style={[styles.action, card, styles.half]} onPress={() => void checkStatus()}>
                <Ionicons name="refresh-outline" size={20} color={isDark ? "#fff" : "#111"} /><Text style={[styles.actionLabel, text]}>Refresh status</Text>
              </TouchableOpacity>
              <TouchableOpacity disabled={!!busy} style={[styles.action, card, styles.half]} onPress={() => void perform("logs")}>
                <Ionicons name="document-text-outline" size={20} color={isDark ? "#fff" : "#111"} /><Text style={[styles.actionLabel, text]}>Open Termux / logs</Text>
              </TouchableOpacity>
            </View>
          </>
        )}

        <View style={[styles.notice, card]}>
          <Text style={[styles.noticeTitle, text]}>One-time Termux setup</Text>
          <Text style={[styles.noticeBody, muted]}>1. Install Termux from F-Droid or the official GitHub release.{"\n"}2. Open Termux → Settings → enable “Allow external apps”.{"\n"}3. Return here and tap Install / Repair. Keep Termux installed; NodRun sends commands to it in the background.</Text>
          <TouchableOpacity style={styles.secondaryButton} onPress={() => openTermux().catch(e => Alert.alert("Could not open Termux", String(e)))}>
            <Text style={styles.secondaryLabel}>Open Termux settings</Text>
          </TouchableOpacity>
        </View>
        <TouchableOpacity style={styles.sessionsButton} onPress={() => router.replace("/(tabs)")}>
          <Text style={styles.sessionsLabel}>Go to Sessions</Text><Ionicons name="arrow-forward" size={18} color="#fff" />
        </TouchableOpacity>
      </ScrollView>
    </View>
  )
}

const styles = StyleSheet.create({
  screen:{flex:1,backgroundColor:"#fff"},screenDark:{backgroundColor:"#0a0a0a"},content:{padding:16,paddingBottom:36,gap:14},
  hero:{padding:20,borderRadius:18,backgroundColor:"#f5f5f5",alignItems:"center",gap:10},heroDark:{backgroundColor:"#151515"},
  iconCircle:{width:62,height:62,borderRadius:31,alignItems:"center",justifyContent:"center",backgroundColor:"#e5e7eb"},iconOnline:{backgroundColor:"#dcfce7"},
  title:{fontSize:22,fontWeight:"700",textAlign:"center"},subtitle:{fontSize:14,lineHeight:21,textAlign:"center"},text:{color:"#111"},textDark:{color:"#f5f5f5"},
  muted:{color:"#666"},mutedDark:{color:"#a1a1aa"},statusRow:{flexDirection:"row",alignItems:"center",gap:8,marginTop:4},dot:{width:9,height:9,borderRadius:5},dotOnline:{backgroundColor:"#16a34a"},dotOffline:{backgroundColor:"#dc2626"},dotUnknown:{backgroundColor:"#a1a1aa"},
  statusText:{fontWeight:"600"},message:{fontSize:12,textAlign:"center"},url:{fontSize:12,fontWeight:"600"},sectionTitle:{fontSize:16,fontWeight:"700",marginTop:4},
  action:{borderRadius:12,padding:14,flexDirection:"row",alignItems:"center",gap:10},primary:{backgroundColor:"#111"},actionText:{flex:1,gap:3},primaryLabel:{color:"#fff",fontWeight:"700",fontSize:14},primaryHint:{color:"#d4d4d4",fontSize:11},actionRow:{flexDirection:"row",gap:10},half:{flex:1,justifyContent:"center",minHeight:54},actionLabel:{fontWeight:"600",fontSize:13},
  card:{backgroundColor:"#f5f5f5"},cardDark:{backgroundColor:"#171717"},notice:{padding:16,borderRadius:12,gap:8},noticeTitle:{fontWeight:"700",fontSize:15},noticeBody:{fontSize:13,lineHeight:21},secondaryButton:{alignSelf:"flex-start",paddingVertical:8,paddingHorizontal:12,borderRadius:8,backgroundColor:"#e5e7eb"},secondaryLabel:{color:"#111",fontWeight:"600"},sessionsButton:{backgroundColor:"#111",padding:15,borderRadius:12,flexDirection:"row",justifyContent:"center",alignItems:"center",gap:8},sessionsLabel:{color:"#fff",fontWeight:"700"}
})
