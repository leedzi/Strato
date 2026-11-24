import SwiftUI
import UniformTypeIdentifiers
import UIKit

struct ICloudSyncView: View {
    @Environment(AppModel.self) private var model
    @State private var choosingFolder = false

    var body: some View {
        Form {
            Section {
                Label("飞行记录随你出发", systemImage: "icloud.fill")
                    .font(.headline).foregroundStyle(Palette.sky)
                Text("在“文件”里选择 iCloud Drive 中的文件夹。其他设备也选同一个文件夹，护照、专注记录和统计会自动合并。")
                    .font(.subheadline)
                Button {
                    choosingFolder = true
                } label: {
                    Label(model.cloudSync.isConnected ? "更换同步文件夹" : "选择 iCloud Drive 文件夹", systemImage: "folder.badge.plus")
                }
                .accessibilityIdentifier("choose-icloud-folder")
            } header: {
                Text("iCloud Drive 同步")
            } footer: {
                Text("请选 iCloud Drive 下的文件夹；选“我的 iPhone”只会在本机保存。连接后的每次记录变更、打开应用和前台运行时都会自动检查同步。")
            }

            Section {
                HStack {
                    Text("状态")
                    Spacer()
                    if model.cloudSync.isSyncing { ProgressView().controlSize(.small) }
                    Text(model.cloudSync.statusText)
                        .font(.subheadline).foregroundStyle(.secondary)
                        .multilineTextAlignment(.trailing)
                }
                if model.cloudSync.isConnected {
                    LabeledContent("文件夹", value: model.cloudSync.folderName)
                    if let date = model.cloudSync.lastSyncedAt {
                        LabeledContent("上次同步") {
                            Text(date, format: .dateTime.month().day().hour().minute())
                                .font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                    Button("现在同步") { model.syncICloudNow() }
                        .disabled(model.cloudSync.isSyncing)
                        .accessibilityIdentifier("sync-icloud-now")
                    Button("断开同步", role: .destructive) { model.disconnectICloud() }
                        .accessibilityIdentifier("disconnect-icloud")
                }
                if let error = model.cloudSync.errorMessage {
                    Text(error).font(.footnote).foregroundStyle(Palette.amber)
                }
            } footer: {
                Text("断开不会删除本机记录或文件夹里的记录。无网络时先保存在本机，网络恢复后再次打开应用即可重试。")
            }

            Section {
                Text("同步飞行记录、登机牌和删除标记；统计随记录重新计算。正在进行的航程、音效和本机权限分别保留在各设备。")
                    .font(.footnote)
                Text("删除或清空记录也会同步到已连接的设备。iCloud 文件传输可能有延迟，两台设备都显示同步完成后再关闭应用。")
                    .font(.footnote).foregroundStyle(.secondary)
            } header: {
                Text("同步内容")
            }
        }
        .navigationTitle("iCloud 同步")
        .navigationBarTitleDisplayMode(.inline)
        .scrollContentBackground(.hidden)
        .background(Palette.backdrop.ignoresSafeArea())
        .sheet(isPresented: $choosingFolder) {
            SyncFolderPicker { url in
                choosingFolder = false
                if let url { model.connectICloudFolder(url) }
            }
        }
    }
}

private struct SyncFolderPicker: UIViewControllerRepresentable {
    var onPick: (URL?) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick) }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.folder])
        picker.allowsMultipleSelection = false
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ controller: UIDocumentPickerViewController, context: Context) {}

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: (URL?) -> Void
        init(onPick: @escaping (URL?) -> Void) { self.onPick = onPick }
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) { onPick(urls.first) }
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) { onPick(nil) }
    }
}
