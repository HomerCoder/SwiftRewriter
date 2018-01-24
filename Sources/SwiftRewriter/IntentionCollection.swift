/// Represents a centralization point where all source code generation intentions
/// are placed and queried for.
public class IntentionCollection {
    private var _intentions: [Intention] = []
    
    public func intentionFor(classNamed name: String) -> ClassGenerationIntention? {
        return intentions().first { $0.typeName == name }
    }
    
    public func intentionFor(structNamed name: String) -> StructGenerationIntention? {
        return intentions().first { $0.typeName == name }
    }
    
    public func intentionFor(enumNamed name: String) -> EnumGenerationIntention? {
        return intentions().first { $0.typeName == name }
    }
    
    public func addIntention(_ intention: Intention) {
        _intentions.append(intention)
    }
    
    public func intentions<T>(ofType type: T.Type = T.self) -> [T] {
        return _intentions.flatMap { $0 as? T }
    }
}
