import GoogleMaps3D
import SwiftUI
import WebKit

@MainActor
struct Google3DSettingsView: View {
    @State private var access = GoogleSceneAccess.shared
    @State private var keyInput = ""
    @State private var notice: String?
    @State private var errorMessage = ""
    @State private var showError = false

    var body: some View {
        @Bindable var access = access
        Form {
            Section {
                Toggle("启用 Google 3D 外景", isOn: $access.isEnabled)
                    .disabled(!access.isConfigured)
                    .accessibilityIdentifier("google3d-enabled-toggle")
                HStack {
                    Text("本机密钥")
                    Spacer()
                    Text(access.isConfigured ? "已配置" : "未配置")
                        .foregroundStyle(access.isConfigured ? Palette.mint : Color.secondary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("google3d-key-status")
                if access.requiresRestart {
                    Text("密钥已变更，请退出并重新打开 Strato 后使用 3D 外景。")
                        .font(.footnote)
                        .foregroundStyle(Palette.amber)
                        .accessibilityIdentifier("google3d-restart-note")
                }
            } footer: {
                Text("默认关闭。保存密钥后，由你手动启用；仅在打开飞行中的 3D 外景页时加载。中国大陆及澳门没有 Google 3D 数据覆盖，国内继续使用离线舷窗。")
            }

            Section {
                SecureField(access.isConfigured ? "输入新密钥以替换" : "输入你的 Google API key", text: $keyInput)
                    .keyboardType(.asciiCapable)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .privacySensitive()
                    .accessibilityIdentifier("google3d-key-field")
                Button(access.isConfigured ? "保存新密钥" : "保存到本机") { saveKey() }
                    .disabled(keyInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityIdentifier("google3d-save-key")
                if access.isConfigured {
                    Button("移除本机密钥", role: .destructive) { clearKey() }
                        .accessibilityIdentifier("google3d-clear-key")
                }
                if let notice {
                    Text(notice).font(.footnote).foregroundStyle(.secondary)
                }
            } header: {
                Text("你的 Google 配置")
            } footer: {
                Text("密钥保存在这台设备的钥匙串中，不显示已保存内容，不随飞行记录导出或同步。Google Cloud 项目需要启用 Maps 3D SDK for iOS 和计费，请求及费用由你的项目承担。建议按官方说明限制密钥的使用范围。")
            }

            Section {
                Link("Google 官方配置说明", destination: URL(string: "https://developers.google.com/maps/documentation/maps-3d/ios-sdk/setup")!)
                    .accessibilityIdentifier("google3d-setup-link")
                Link("查看 Google 3D 数据覆盖", destination: URL(string: "https://developers.google.com/maps/coverage")!)
                    .accessibilityIdentifier("google3d-coverage-link")
                NavigationLink {
                    Google3DLicenseView()
                        .navigationTitle("开源许可证")
                        .navigationBarTitleDisplayMode(.inline)
                } label: {
                    Text("Google Maps 开源许可证")
                }
                .accessibilityIdentifier("google3d-licenses-link")
            } footer: {
                Text("3D 外景展示真实地形重建，不是实时天气或实拍画面。加载失败时会显示 Google 的提示，可关闭外景继续使用离线舷窗。")
            }
        }
        .scrollContentBackground(.hidden)
        .background(Palette.backdrop.ignoresSafeArea())
        .navigationTitle("Google 3D 外景")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("google3d-settings-view")
        .onAppear { access.refreshConfiguration() }
        .onDisappear { keyInput = "" }
        .alert("Google 3D 配置", isPresented: $showError) {
            Button("好", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }

    private func saveKey() {
        do {
            try access.saveKey(keyInput)
            keyInput = ""
            notice = access.requiresRestart ? "新的密钥已保存在本机。" : "密钥已保存在本机，可以手动打开上方开关。"
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    private func clearKey() {
        do {
            try access.clearKey()
            keyInput = ""
            notice = "本机密钥已移除，3D 外景已关闭。"
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}

/// The SDK supplies the license text locally. Embedded web content cannot make network requests.
@MainActor
private struct Google3DLicenseView: UIViewRepresentable {
    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = false
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.isOpaque = false
        webView.backgroundColor = .clear
        let source = GoogleMaps3D.Map.openSourceLicenseInfo
        let content: String
        if source.range(of: "<(html|body|div|p|br)\\b", options: [.regularExpression, .caseInsensitive]) != nil {
            content = source
        } else {
            let escaped = source.replacingOccurrences(of: "&", with: "&amp;")
                .replacingOccurrences(of: "<", with: "&lt;")
                .replacingOccurrences(of: ">", with: "&gt;")
            content = "<pre>\(escaped)</pre>"
        }
        webView.loadHTMLString("""
            <!doctype html><html><head><meta charset="utf-8">
            <meta http-equiv="Content-Security-Policy" content="default-src 'none'; style-src 'unsafe-inline'">
            <meta name="viewport" content="width=device-width, initial-scale=1">
            <style>html { color-scheme: light dark; } body { font: 14px -apple-system; line-height: 1.5; padding: 12px; overflow-wrap: anywhere; } pre { white-space: pre-wrap; font: inherit; }</style>
            </head><body>\(content)</body></html>
            """, baseURL: nil)
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    final class Coordinator: NSObject, WKNavigationDelegate {
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            decisionHandler(navigationAction.request.url?.scheme == "about" ? .allow : .cancel)
        }
    }
}
