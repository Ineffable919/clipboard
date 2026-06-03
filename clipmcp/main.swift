import Foundation

let handler = MCPHandler()

while let line = readLine(strippingNewline: true) {
    guard !line.isEmpty else { continue }
    guard let response = handler.handle(line: line) else { continue }
    FileHandle.standardOutput.write(Data((response + "\n").utf8))
}
