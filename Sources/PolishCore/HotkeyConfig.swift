public struct HotkeyConfig: Codable, Equatable, Sendable {
    public var keyCode: UInt32
    public var command: Bool
    public var option: Bool
    public var shift: Bool
    public var control: Bool

    public init(keyCode: UInt32, command: Bool, option: Bool, shift: Bool, control: Bool) {
        self.keyCode = keyCode
        self.command = command
        self.option = option
        self.shift = shift
        self.control = control
    }

    /// Option+Command+P
    public static let `default` = HotkeyConfig(
        keyCode: 35, command: true, option: true, shift: false, control: false
    )
}
