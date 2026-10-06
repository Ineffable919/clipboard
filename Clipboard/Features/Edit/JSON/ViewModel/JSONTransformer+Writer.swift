import Foundation

extension JSONTransformer {
    nonisolated struct TreeWriter {
        let source: [UInt8]
        let indentation: Int
        let ascending: Bool?
        let naming: JSONKeyNaming?
        var output: [UInt8] = []

        init(
            source: [UInt8],
            indentation: Int,
            ascending: Bool?,
            naming: JSONKeyNaming?
        ) {
            self.source = source
            self.indentation = indentation
            self.ascending = ascending
            self.naming = naming
            output.reserveCapacity(source.count + source.count / 8)
        }

        mutating func write(_ node: Node, depth: Int = 0) throws {
            try JSONTransformer.checkCancellation()

            switch node {
            case let .scalar(range):
                output.append(contentsOf: source[range])
            case let .array(values):
                try writeArray(values, depth: depth)
            case let .object(members):
                try writeObject(members, depth: depth)
            }
        }

        private mutating func writeArray(_ values: [Node], depth: Int) throws {
            output.append(Byte.leftBracket)
            guard !values.isEmpty else {
                output.append(Byte.rightBracket)
                return
            }

            appendNewline(depth: depth + 1)
            for (index, value) in values.enumerated() {
                try write(value, depth: depth + 1)
                if index < values.count - 1 {
                    output.append(Byte.comma)
                    appendNewline(depth: depth + 1)
                }
            }
            appendNewline(depth: depth)
            output.append(Byte.rightBracket)
        }

        private mutating func writeObject(_ members: [Member], depth: Int) throws {
            let prepared = try prepare(members)
            output.append(Byte.leftBrace)
            guard !prepared.isEmpty else {
                output.append(Byte.rightBrace)
                return
            }

            appendNewline(depth: depth + 1)
            for (index, member) in prepared.enumerated() {
                if let renamedKey = member.renamedKey {
                    JSONTransformer.appendJSONString(renamedKey, to: &output)
                } else {
                    output.append(contentsOf: source[member.member.rawKeyRange])
                }
                output.append(contentsOf: [Byte.colon, Byte.space])
                try write(member.member.value, depth: depth + 1)
                if index < prepared.count - 1 {
                    output.append(Byte.comma)
                    appendNewline(depth: depth + 1)
                }
            }
            appendNewline(depth: depth)
            output.append(Byte.rightBrace)
        }

        private func prepare(_ members: [Member]) throws -> [PreparedMember] {
            var prepared = members.map { member in
                PreparedMember(
                    member: member,
                    renamedKey: naming.map { JSONTransformer.rename(member.key, as: $0) }
                )
            }

            if naming != nil {
                var keys = Set<String>()
                for member in prepared {
                    let key = member.renamedKey ?? member.member.key
                    guard keys.insert(key).inserted else {
                        throw JSONTransformError.duplicateKey(key)
                    }
                }
            }

            if let ascending {
                prepared.sort { lhs, rhs in
                    let left = lhs.renamedKey ?? lhs.member.key
                    let right = rhs.renamedKey ?? rhs.member.key
                    return ascending ? left < right : left > right
                }
            }

            return prepared
        }

        private mutating func appendNewline(depth: Int) {
            output.append(Byte.newline)
            guard indentation > 0 else { return }
            output.append(contentsOf: repeatElement(
                Byte.space,
                count: depth * indentation
            ))
        }
    }

    nonisolated struct PreparedMember {
        let member: Member
        let renamedKey: String?
    }

}
