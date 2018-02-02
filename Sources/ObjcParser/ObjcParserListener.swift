import GrammarModels
import Antlr4
import ObjcParserAntlr

internal class ObjcParserListener: ObjectiveCParserBaseListener {
    let context: NodeCreationContext
    let rootNode: GlobalContextNode
    private let mapper: GenericParseTreeContextMapper
    
    override init() {
        context = NodeCreationContext()
        context.autoUpdatesSourceRange = false
        rootNode = GlobalContextNode()
        mapper = GenericParseTreeContextMapper()
        
        super.init()
        
        configureMappers()
    }
    
    // Helper for mapping Objective-C types from raw strings into a structured types
    private static func parseObjcType(_ source: String) -> ObjcType? {
        let parser = ObjcParser(source: StringCodeSource(source: source))
        return try? parser.parseObjcType()
    }
    
    // Helper for mapping Objective-C types from type declarations into structured
    // types.
    private static func parseObjcType(inDeclaration decl: ObjectiveCParser.FieldDeclarationContext) -> ObjcType? {
        guard let specQualifier = decl.specifierQualifierList() else {
            return nil
        }
        guard let baseTypeString = specQualifier.typeSpecifier(0)?.getText() else {
            return nil
        }
        guard let declarator = decl.fieldDeclaratorList()?.fieldDeclarator(0)?.declarator() else {
            return nil
        }
        
        let pointerDecl = declarator.pointer()
        
        var typeName = "\(baseTypeString) \(pointerDecl.map { $0.getText() } ?? "")"
        
        if specQualifier.arcBehaviourSpecifier().count > 0 {
            let arcSpecifiers =
                specQualifier.arcBehaviourSpecifier().map {
                    $0.getText()
                }
            
            typeName = "\(arcSpecifiers.joined(separator: " ")) \(typeName)"
        }
        
        guard let type = ObjcParserListener.parseObjcType(typeName) else {
            return nil
        }
        
        return type
    }
    
    /// Configures mappers in `self.mapper` so they are automatically pushed and
    /// popped whenever the rules are entered and exited during visit.
    ///
    /// Used as a convenience over manually pushing and popping contexts every time
    /// a node of significance is entered.
    private func configureMappers() {
        mapper.addRuleMap(rule: ObjectiveCParser.TranslationUnitContext.self, node: rootNode)
        mapper.addRuleMap(rule: ObjectiveCParser.ClassInterfaceContext.self, nodeType: ObjcClassInterface.self)
        mapper.addRuleMap(rule: ObjectiveCParser.MethodDeclarationContext.self, nodeType: MethodDefinition.self)
        mapper.addRuleMap(rule: ObjectiveCParser.PropertyDeclarationContext.self, nodeType: PropertyDefinition.self)
        mapper.addRuleMap(rule: ObjectiveCParser.PropertyAttributesListContext.self, nodeType: PropertyModifierList.self)
        mapper.addRuleMap(rule: ObjectiveCParser.KeywordDeclaratorContext.self, nodeType: KeywordDeclarator.self)
        mapper.addRuleMap(rule: ObjectiveCParser.MethodSelectorContext.self, nodeType: MethodSelector.self)
        mapper.addRuleMap(rule: ObjectiveCParser.MethodTypeContext.self, nodeType: MethodType.self)
        mapper.addRuleMap(rule: ObjectiveCParser.ProtocolListContext.self, nodeType: ProtocolReferenceList.self)
        mapper.addRuleMap(rule: ObjectiveCParser.InstanceVariablesContext.self, nodeType: IVarsList.self)
    }
    
    override func enterEveryRule(_ ctx: ParserRuleContext) {
        mapper.matchEnter(ruleType: type(of: ctx), context: context)
    }
    
    override func exitEveryRule(_ ctx: ParserRuleContext) {
        mapper.matchExit(ruleType: type(of: ctx), context: context)
    }
    
    // MARK: - Class Interface
    override func enterClassInterface(_ ctx: ObjectiveCParser.ClassInterfaceContext) {
        guard let classNode = context.currentContextNode(as: ObjcClassInterface.self) else {
            return
        }
        
        // Class name
        if let ident = ctx.className?.identifier()?.getText() {
            classNode.identifier = .valid(Identifier(name: ident))
        }
        
        // Super class name
        if let sup = ctx.superclassName?.getText() {
            context.addChildNode(SuperclassName(name: sup))
        }
    }
    
    override func enterProtocolName(_ ctx: ObjectiveCParser.ProtocolNameContext) {
        guard let node = context.currentContextNode(as: ProtocolReferenceList.self) else {
            return
        }
        
        if let ident = ctx.identifier()?.getText() {
            node.addChild(ProtocolName(name: ident))
        }
    }
    
    // MARK: - Instance Variables
    override func enterAccessModifier(_ ctx: ObjectiveCParser.AccessModifierContext) {
        if ctx.PRIVATE() != nil {
            context.addChildNode(KeywordNode(keyword: .atPrivate))
        } else if ctx.PACKAGE() != nil {
            context.addChildNode(KeywordNode(keyword: .atPackage))
        } else if ctx.PROTECTED() != nil {
            context.addChildNode(KeywordNode(keyword: .atProtected))
        } else if ctx.PUBLIC() != nil {
            context.addChildNode(KeywordNode(keyword: .atPublic))
        }
    }
    
    override func enterVisibilitySection(_ ctx: ObjectiveCParser.VisibilitySectionContext) {
        let declarations = ctx.fieldDeclaration()
        
        for decl in declarations {
            guard let declarator = decl.fieldDeclaratorList()?.fieldDeclarator(0)?.declarator() else {
                continue
            }
            guard let identString = declarator.directDeclarator()?.identifier()?.getText() else {
                continue
            }
            
            guard let type = ObjcParserListener.parseObjcType(inDeclaration: decl) else {
                continue
            }
            
            let typeNode = TypeNameNode(type: type)
            let ident = Identifier(name: identString)
            
            let ivar = IVarDeclaration()
            ivar.addChild(typeNode)
            ivar.addChild(ident)
            
            context.addChildNode(ivar)
        }
    }
    
    // MARK: - Property Declaration
    override func enterPropertyDeclaration(_ ctx: ObjectiveCParser.PropertyDeclarationContext) {
        if let ident =
            ctx.fieldDeclaration()?
                .fieldDeclaratorList()?
                .fieldDeclarator(0)?
                .declarator()?
                .directDeclarator()?
                .identifier() {
            
            context.addChildNode(Identifier(name: ident.getText()))
        }
        
        if let fieldDeclaration = ctx.fieldDeclaration() {
            if let type = ObjcParserListener.parseObjcType(inDeclaration: fieldDeclaration) {
                let typeNode = TypeNameNode(type: type)
                context.addChildNode(typeNode)
            }
        }
    }
    
    override func enterPropertyAttribute(_ ctx: ObjectiveCParser.PropertyAttributeContext) {
        let modifier: PropertyModifier.Modifier
        
        if let ident = ctx.identifier()?.getText() {
            if ctx.GETTER() != nil {
                modifier = .getter(ident)
            } else if ctx.SETTER() != nil {
                modifier = .setter(ident)
            } else {
                modifier = .keyword(ident)
            }
        } else {
            modifier = .keyword(ctx.getText())
        }
        
        let node = PropertyModifier(modifier: modifier)
        
        context.addChildNode(node)
    }
    
    override func enterTypeName(_ ctx: ObjectiveCParser.TypeNameContext) {
        guard let typeSpec = ctx.specifierQualifierList()?.typeSpecifier(0)?.getText() else {
            return
        }
        
        let abstract = ctx.abstractDeclarator()?.getText() ?? ""
        
        guard let type = ObjcParserListener.parseObjcType(typeSpec + abstract) else {
            return
        }
        
        let node = TypeNameNode(type: type)
        context.addChildNode(node)
    }
    
    override func enterGenericTypeSpecifier(_ ctx: ObjectiveCParser.GenericTypeSpecifierContext) {
        mapper.pushTemporaryException(forRuleType: ObjectiveCParser.ProtocolListContext.self)
    }
    
    override func exitGenericTypeSpecifier(_ ctx: ObjectiveCParser.GenericTypeSpecifierContext) {
        mapper.popTemporaryException()
    }
    
    override func enterNullabilitySpecifier(_ ctx: ObjectiveCParser.NullabilitySpecifierContext) {
        let spec = NullabilitySpecifier(name: ctx.getText())
        context.addChildNode(spec)
    }
    
    override func enterKeywordDeclarator(_ ctx: ObjectiveCParser.KeywordDeclaratorContext) {
        guard let node = context.currentContextNode(as: KeywordDeclarator.self) else {
            return
        }
        
        let selectorIdent =
            (ctx.selector()?.identifier()).map {
                Identifier(name: $0.getText())
        }
        
        let ident =
            ctx.identifier().map { Identifier(name: $0.getText()) }
        
        if let ident = selectorIdent {
            node.addChild(ident)
        }
        if let ident = ident {
            node.addChild(ident)
        }
    }
    
    // MARK: - Method Declaration
    override func enterMethodSelector(_ ctx: ObjectiveCParser.MethodSelectorContext) {
        if let selIdentifier = ctx.selector()?.identifier() {
            context.addChildNode(Identifier(name: selIdentifier.getText()))
        }
    }
}

private class GenericParseTreeContextMapper {
    typealias NodeType = ASTNode & InitializableNode
    
    private var pairs: [Pair] = []
    private var exceptions: [ParserRuleContext.Type] = []
    
    func addRuleMap<T: ParserRuleContext, U: NodeType>(rule: T.Type, nodeType: U.Type) {
        assert(match(ruleType: rule) == nil, "Duplicated mapping rule for parser rule context \(rule)")
        
        pairs.append(.type(rule: rule, nodeType: nodeType))
    }
    
    func addRuleMap<T: ParserRuleContext, U: NodeType>(rule: T.Type, node: U) {
        assert(match(ruleType: rule) == nil, "Duplicated mapping rule for parser rule context \(rule)")
        
        pairs.append(.instance(rule: rule, node: node))
    }
    
    func pushTemporaryException(forRuleType ruleType: ParserRuleContext.Type) {
        exceptions.append(ruleType)
    }
    
    func popTemporaryException() {
        exceptions.removeLast()
    }
    
    func matchEnter(ruleType: ParserRuleContext.Type, context: NodeCreationContext) {
        guard let nodeType = match(ruleType: ruleType) else {
            return
        }
        
        switch nodeType {
        case .type(_, let nodeType):
            let node = nodeType.init()
            context.pushContext(node: node)
        case .instance(_, let node):
            context.pushContext(node: node)
        }
    }
    
    func matchExit(ruleType: ParserRuleContext.Type, context: NodeCreationContext) {
        guard let pair = match(ruleType: ruleType) else {
            return
        }
        
        if let popped = context.popContext() {
            switch pair {
            case .type(_, let nodeType):
                assert(type(of: popped) == nodeType)
            case .instance(_, let node):
                assert(popped === node)
            }
        }
    }
    
    private func match(ruleType: ParserRuleContext.Type) -> Pair? {
        if exceptions.contains(where: { $0 == ruleType }) {
            return nil
        }
        
        return pairs.first { $0.ruleType == ruleType }
    }
    
    private enum Pair {
        case type(rule: ParserRuleContext.Type, nodeType: NodeType.Type)
        case instance(rule: ParserRuleContext.Type, node: NodeType)
        
        var ruleType: ParserRuleContext.Type {
            switch self {
            case .type(let rule, _):
                return rule
            case .instance(let rule, _):
                return rule
            }
        }
    }
}
