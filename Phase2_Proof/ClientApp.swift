import Foundation
import ServiceManagement

@main
struct ClientMain {
    static func main() {
        let connection = NSXPCConnection(machServiceName: "com.macdictation.recorder", options: [])
        connection.remoteObjectInterface = NSXPCInterface(with: RecorderXPCProtocol.self)
        connection.resume()

        guard let proxy = connection.remoteObjectProxyWithErrorHandler({ error in
            print("XPC Error: \(error.localizedDescription)")
            exit(1)
        }) as? RecorderXPCProtocol else {
            print("Failed to cast proxy")
            exit(1)
        }

        print("Starting recording...")
        let group = DispatchGroup()
        group.enter()

        proxy.startRecording { success, msg in
            if success {
                print("Success: \(msg ?? "")")
            } else {
                print("Failed: \(msg ?? "")")
            }
            group.leave()
        }
        group.wait()

        print("Recording for 5 seconds...")
        sleep(5)

        group.enter()
        proxy.stopRecording { success in
            print("Stopped recording")
            group.leave()
        }
        group.wait()

        print("Done. Check Documents directory for the CAF file.")
    }
}
