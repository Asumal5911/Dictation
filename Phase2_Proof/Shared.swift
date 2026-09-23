import Foundation

@objc protocol RecorderXPCProtocol {
    func startRecording(reply: @escaping (Bool, String?) -> Void)
    func stopRecording(reply: @escaping (Bool) -> Void)
    func getStatus(reply: @escaping (String) -> Void)
}
