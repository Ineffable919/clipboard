//
//  MarkdownHTMLRenderer+Stylesheet.swift
//  Clipboard
//
//  Markdown 预览样式。
//

import Foundation

nonisolated extension MarkdownHTMLRenderer {
    static let stylesheet = """
    :root {
        color-scheme: light dark;
        --page: rgb(255, 255, 255);
        --text: rgb(31, 35, 40);
        --muted: rgb(89, 99, 110);
        --link: rgb(0, 97, 201);
        --border: rgba(31, 35, 40, 0.16);
        --soft-border: rgba(31, 35, 40, 0.10);
        --code-bg: rgba(175, 184, 193, 0.20);
        --pre-bg: rgb(246, 248, 250);
        --quote-bg: rgba(9, 105, 218, 0.05);
        --table-head: rgba(175, 184, 193, 0.18);
    }

    @media (prefers-color-scheme: dark) {
        :root {
            --page: rgb(30, 30, 30);
            --text: rgb(230, 237, 243);
            --muted: rgb(139, 148, 158);
            --link: rgb(88, 166, 255);
            --border: rgba(240, 246, 252, 0.18);
            --soft-border: rgba(240, 246, 252, 0.10);
            --code-bg: rgba(110, 118, 129, 0.36);
            --pre-bg: rgb(22, 27, 34);
            --quote-bg: rgba(88, 166, 255, 0.10);
            --table-head: rgba(110, 118, 129, 0.22);
        }
    }

    * {
        box-sizing: border-box;
    }

    html {
        background: var(--page);
        color: var(--text);
        font: -apple-system-body;
        overflow-wrap: anywhere;
    }

    body {
        margin: 0;
        padding: 12px 14px 14px;
        background: var(--page);
        color: var(--text);
        line-height: 1.48;
        -webkit-font-smoothing: antialiased;
    }

    #markdown-content > :first-child {
        margin-top: 0;
    }

    #markdown-content > :last-child {
        margin-bottom: 0;
    }

    .md-frontmatter {
        margin: 0 0 1.2em;
        padding: 0 0 1em;
        border-bottom: 1px solid var(--border);
    }

    .md-frontmatter table {
        display: table;
        width: 100%;
        table-layout: fixed;
        margin: 0;
        overflow: visible;
        font-size: 0.92em;
        line-height: 1.5;
    }

    .md-frontmatter th,
    .md-frontmatter td {
        padding: 0.28em 0;
        border: 0;
        vertical-align: baseline;
        overflow-wrap: anywhere;
        text-align: left;
    }

    .md-frontmatter th {
        width: 26%;
        padding-right: 1.4em;
        color: var(--muted);
        font-weight: 500;
    }

    .md-frontmatter td {
        white-space: pre-wrap;
    }

    .md-fm-pill {
        display: inline-block;
        margin: 0 0.4em 0.2em 0;
        padding: 0.08em 0.7em;
        border-radius: 999px;
        background: color-mix(in srgb, var(--link) 12%, transparent);
        color: var(--link);
        font-size: 0.95em;
    }

    .md-fm-empty::before {
        content: "—";
        color: var(--muted);
    }

    h1, h2, h3, h4, h5, h6 {
        margin: 1.05em 0 0.45em;
        color: var(--text);
        font-weight: 650;
        line-height: 1.22;
    }

    h1 {
        padding-bottom: 0.28em;
        border-bottom: 1px solid var(--soft-border);
        font-size: 1.65em;
    }

    h2 {
        padding-bottom: 0.22em;
        border-bottom: 1px solid var(--soft-border);
        font-size: 1.38em;
    }

    h3 { font-size: 1.18em; }
    h4 { font-size: 1.05em; }
    h5, h6 {
        color: var(--muted);
        font-size: 1em;
    }

    p, blockquote, ul, ol, dl, table, pre {
        margin: 0.72em 0;
    }

    a {
        color: var(--link);
        text-decoration: none;
    }

    a:hover {
        text-decoration: underline;
    }

    strong {
        font-weight: 650;
    }

    code, pre {
        font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace;
        font-size: 0.92em;
    }

    code {
        padding: 0.13em 0.34em;
        border-radius: 5px;
        background: var(--code-bg);
    }

    pre {
        overflow: auto;
        padding: 12px;
        border: 1px solid var(--soft-border);
        border-radius: 8px;
        background: var(--pre-bg);
        line-height: 1.45;
    }

    pre code {
        display: block;
        padding: 0;
        border-radius: 0;
        background: transparent;
        white-space: pre;
        overflow-wrap: normal;
    }

    blockquote {
        margin-left: 0;
        padding: 8px 12px;
        border-left: 3px solid var(--link);
        border-radius: 0 8px 8px 0;
        background: var(--quote-bg);
        color: var(--muted);
    }

    blockquote > :first-child {
        margin-top: 0;
    }

    blockquote > :last-child {
        margin-bottom: 0;
    }

    .markdown-alert {
        margin: 0.8em 0;
        padding: 10px 14px;
        border-left: 4px solid var(--border);
        border-radius: 0 8px 8px 0;
        background: var(--quote-bg);
        color: var(--text);
    }

    .markdown-alert > :last-child {
        margin-bottom: 0;
    }

    .markdown-alert-title {
        display: flex;
        align-items: center;
        margin: 0;
        font-weight: 650;
        line-height: 1;
    }

    .markdown-alert-icon {
        width: 1em;
        height: 1em;
        margin-right: 0.5em;
        fill: currentColor;
        flex: 0 0 auto;
    }

    .markdown-alert-note { border-left-color: #0969da; }
    .markdown-alert-note .markdown-alert-title { color: #0969da; }
    .markdown-alert-tip { border-left-color: #1a7f37; }
    .markdown-alert-tip .markdown-alert-title { color: #1a7f37; }
    .markdown-alert-important { border-left-color: #8250df; }
    .markdown-alert-important .markdown-alert-title { color: #8250df; }
    .markdown-alert-warning { border-left-color: #9a6700; }
    .markdown-alert-warning .markdown-alert-title { color: #9a6700; }
    .markdown-alert-caution { border-left-color: #d1242f; }
    .markdown-alert-caution .markdown-alert-title { color: #d1242f; }

    ul, ol {
        padding-left: 1.55em;
    }

    li {
        margin: 0.22em 0;
    }

    li > p {
        margin: 0.28em 0;
    }

    li.task-list-item {
        list-style: none;
    }

    li.task-list-item > p:first-of-type {
        display: inline;
        margin-top: 0;
    }

    .task-list-item-checkbox {
        margin: 0 0.42em 0 -1.3em;
        vertical-align: -0.1em;
        accent-color: var(--link);
    }

    li.task-list-item:has(input.task-list-item-checkbox:checked) {
        color: var(--muted);
        text-decoration: line-through;
    }

    hr {
        height: 1px;
        margin: 1.05em 0;
        border: 0;
        background: var(--border);
    }

    table {
        width: 100%;
        border-collapse: collapse;
        display: block;
        overflow-x: auto;
        border-spacing: 0;
    }

    th, td {
        padding: 7px 9px;
        border: 1px solid var(--border);
        vertical-align: top;
    }

    th {
        background: var(--table-head);
        font-weight: 650;
    }

    .footnote-ref {
        font-size: 0.75em;
        line-height: 0;
        vertical-align: super;
    }

    .footnote-ref a {
        padding: 0 0.12em;
    }

    .footnotes {
        margin-top: 2.35em;
        font-size: 0.9em;
        line-height: 1.45;
    }

    .footnotes ol {
        margin-top: 0;
        padding-left: 1.45em;
    }

    .footnotes li {
        margin-top: 0.72em;
    }

    .footnote-backrefs {
        display: inline-flex;
        gap: 0.28em;
        margin-left: 0.28em;
        white-space: nowrap;
    }

    .footnote-backref {
        font-size: 0.78em;
        opacity: 0.65;
    }

    .footnote-backref:hover {
        opacity: 1;
    }

    details {
        margin: 0.72em 0;
        padding: 8px 10px;
        border: 1px solid var(--soft-border);
        border-radius: 8px;
    }

    summary {
        cursor: pointer;
        font-weight: 600;
    }

    kbd {
        padding: 0.1em 0.38em;
        border: 1px solid var(--border);
        border-bottom-width: 2px;
        border-radius: 5px;
        background: var(--pre-bg);
        font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace;
        font-size: 0.86em;
    }

    img, video {
        max-width: 100%;
        height: auto;
        border-radius: 8px;
    }

    img {
        display: block;
        margin: 0.8em 0;
    }
    """
}
