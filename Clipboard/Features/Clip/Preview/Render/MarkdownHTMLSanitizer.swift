//
//  MarkdownHTMLSanitizer.swift
//  Clipboard
//
//  在独立脚本环境中使用本地 DOMPurify 清理 Markdown 原始 HTML。
//

import Foundation
import WebKit

enum MarkdownHTMLSanitizer {
    private static let contentWorld = WKContentWorld.world(name: "ClipboardMarkdownSanitizer")

    // Keep the isolated browser bootstrap together so its execution order is explicit.
    private static func bootstrapScript(highlightStylesheet: String?) -> String {
        let stylesheet = javaScriptStringLiteral(highlightStylesheet ?? "")
        return bootstrapScriptPrefix + stylesheet + bootstrapScriptSuffix
    }

    private static let bootstrapScriptPrefix = """
    (() => {
        const source = document.getElementById('markdown-source');
        const content = document.getElementById('markdown-content');
        if (!source || !content || typeof DOMPurify === 'undefined' || !DOMPurify.sanitize) {
            source?.remove();
            return;
        }

        const allowedURI = new RegExp(
            '^(?:(?:(?:f|ht)tps?|mailto|tel|callto|sms|cid|xmpp|matrix):|' +
            '[^a-z]|[a-z+.\\\\-]+(?:[^a-z+.\\\\-:]|$))',
            'i'
        );
        const config = {
            FORBID_TAGS: ['style', 'form', 'iframe', 'object', 'embed', 'meta', 'link', 'base'],
            FORBID_ATTR: ['style'],
            ADD_ATTR: ['target'],
            ALLOWED_URI_REGEXP: allowedURI
        };
        content.innerHTML = DOMPurify.sanitize(source.value, config);
        source.remove();

    """
        + "        const highlightStylesheet = "

    private static let bootstrapScriptSuffix = """
    ;
        if (highlightStylesheet) {
            const style = document.createElement('style');
            style.textContent = highlightStylesheet;
            document.head.appendChild(style);
        }

        if (typeof hljs === 'undefined' || !hljs.highlightElement) return;
        const blocks = Array.from(document.querySelectorAll('pre > code'));
        const candidates = [
            'javascript', 'typescript', 'python', 'json', 'css', 'xml',
            'bash', 'swift', 'go', 'ruby', 'rust', 'c', 'cpp', 'java',
            'kotlin', 'csharp', 'sql', 'yaml', 'toml'
        ];
        let index = 0;
        function highlightNextBatch() {
            const start = performance.now();
            while (index < blocks.length) {
                const block = blocks[index++];
                try {
                    const explicit = Array.from(block.classList)
                        .some((name) => name.startsWith('language-'));
                    if (explicit) {
                        hljs.highlightElement(block);
                    } else {
                        const result = hljs.highlightAuto(block.textContent || '', candidates);
                        if (result && result.relevance >= 2) {
                            block.innerHTML = result.value;
                            block.classList.add('hljs', 'language-' + result.language);
                        }
                    }
                } catch (_) {}
                if (performance.now() - start > 8) break;
            }
            if (index < blocks.length) requestAnimationFrame(highlightNextBatch);
        }
        requestAnimationFrame(highlightNextBatch);
    })();
    """

    static func install(in contentController: WKUserContentController) {
        guard let domPurifyScript else { return }

        contentController.addUserScript(WKUserScript(
            source: domPurifyScript,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true,
            in: contentWorld
        ))
        let runtimeScript = [
            highlightScript,
            bootstrapScript(highlightStylesheet: highlightStylesheet)
        ].compactMap(\.self).joined(separator: "\n")
        contentController.addUserScript(WKUserScript(
            source: runtimeScript,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: true,
            in: contentWorld
        ))
    }

    private static let domPurifyScript = bundledResource(
        "purify.min",
        extension: "js",
        subdirectory: "DOMPurify"
    )

    private static let highlightScript: String? = {
        guard let script = bundledResource(
            "highlight.min",
            extension: "js",
            subdirectory: "Highlight"
        ) else {
            return nil
        }
        // WKUserScript files have separate top-level scopes. Export the
        // library explicitly so the later bootstrap script can use it.
        return script + "\n;globalThis.hljs = hljs;"
    }()

    private static let highlightStylesheet = bundledResource(
        "highlight.min",
        extension: "css",
        subdirectory: "Highlight"
    )

    private static func bundledResource(
        _ name: String,
        extension fileExtension: String,
        subdirectory: String
    ) -> String? {
        let url = Bundle.main.url(
            forResource: name,
            withExtension: fileExtension,
            subdirectory: subdirectory
        ) ?? Bundle.main.url(forResource: name, withExtension: fileExtension)
        guard let url else { return nil }
        return try? String(contentsOf: url, encoding: .utf8)
    }

    private static func javaScriptStringLiteral(_ string: String) -> String {
        guard let data = try? JSONEncoder().encode(string),
              let result = String(data: data, encoding: .utf8) else {
            return "\"\""
        }
        return result
    }
}
