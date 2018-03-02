import Foundation
import Utility
import Console
import SwiftRewriterLib

let parser =
    ArgumentParser(
        usage: "[--colorize] [--print-expression-types] [--print-tracing-history] [--verbose] [files <files...> | path <path> [--exclude-pattern <pattern>] [--skip-confirm]]",
        overview: """
            Converts a set of files, or, if not provided, starts an interactive menu to navigate the file system and choose files to convert.
            """)

// --colorize
let colorArg: OptionArgument<Bool> =
    parser.add(option: "--colorize", kind: Bool.self, usage: "Pass this parameter as true to enable terminal colorization during output.")

// --print-expression-types
let outputExpressionTypesArg: OptionArgument<Bool> =
    parser.add(option: "--print-expression-types",
               kind: Bool.self,
               usage: "Prints the type of each top-level resolved expression statement found in function bodies.")

// --print-tracing-history
let outputIntentionHistoryArg: OptionArgument<Bool> =
    parser.add(option: "--print-tracing-history",
               kind: Bool.self,
               usage: """
        Prints extra information before each declaration and member about the \
        inner logical decisions of intention passes as they change the structure \
        of declarations.
        """)

// --verbose
let verboseArg: OptionArgument<Bool> =
    parser.add(option: "--verbose",
               kind: Bool.self,
               usage: "Prints progress information to the console while performing a transpiling job.")

// files <files...>

let filesParser =
    parser.add(subparser: "files",
               overview: "Converts one or more series of files to Swift and print them to the terminal.")
let filesArg: PositionalArgument<[String]> =
    filesParser.add(positional: "files", kind: [String].self, usage: "Objective-C file(s) to convert.")

// path <path> [--exclude-pattern <pattern>] [--skip-confirm]

let pathParser =
    parser.add(subparser: "path",
               overview: "Examines a path and collects all .h/.m files to convert, before presenting a prompt to confirm conversion of files.")
let pathArg: PositionalArgument<String> =
    pathParser.add(positional: "path", kind: String.self, usage: "Path to the project to inspect")
let excludePatternArg: OptionArgument<String> =
    pathParser.add(option: "--exclude-pattern", kind: String.self, usage: "Provides a regex-like pattern for excluding matches from the initial Objective-C files search. Pattern is applied to the full path.")
let skipConfirmArg: OptionArgument<Bool> =
    pathParser.add(option: "--skip-confirm", kind: Bool.self, usage: "Skipts asking for confirmation prior to parsing")

do {
    let arguments = Array(ProcessInfo.processInfo.arguments.dropFirst())
    
    let result = try parser.parse(arguments)
    
    let colorize = result.get(colorArg) ?? false
    
    options.outputExpressionTypes = result.get(outputExpressionTypesArg) ?? false
    options.printIntentionHistory = result.get(outputIntentionHistoryArg) ?? false
    
    verbose = result.get(verboseArg) ?? false
    
    if result.subparser(parser) == "files" {
        guard let files = result.get(filesArg) else {
            throw Utility.ArgumentParserError.expectedValue(option: "<files...>")
        }
        
        let output = StdoutWriterOutput(colorize: colorize)
        
        let rewriter: SwiftRewriterService = SwiftRewriterServiceImpl(output: output)
        try rewriter.rewrite(files: files.map { URL(fileURLWithPath: $0) })
        
    } else if result.subparser(parser) == "path" {
        guard let path = result.get(pathArg) else {
            throw Utility.ArgumentParserError.expectedValue(option: "<path>")
        }
        
        let skipConfirm = result.get(skipConfirmArg) ?? false
        let excludePattern = result.get(excludePatternArg)
        
        let service = SwiftRewriterServiceImpl.fileDiskService
        
        let console = Console()
        let menu = Menu(rewriterService: service, console: console)
        
        let interface = SuggestConversionInterface(rewriterService: service)
        interface.searchAndShowConfirm(in: menu,
                                       path: path,
                                       skipConfirm: skipConfirm,
                                       excludePattern: excludePattern)
    } else {
        let output = StdoutWriterOutput(colorize: colorize)
        let service = SwiftRewriterServiceImpl(output: output)
        let console = Console()
        let menu = Menu(rewriterService: service, console: console)
        
        menu.main()
    }
} catch {
    print("Error: \(error)")
}
