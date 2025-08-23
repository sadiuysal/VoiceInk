import SwiftUI
import AppKit

struct HTMLTextView: View {
    let htmlString: String
    let maxHeight: CGFloat?
    
    init(_ htmlString: String, maxHeight: CGFloat? = nil) {
        self.htmlString = htmlString
        self.maxHeight = maxHeight
    }
    
    var body: some View {
        HTMLTextRepresentable(htmlString: htmlString, maxHeight: maxHeight)
    }
}

struct HTMLTextRepresentable: NSViewRepresentable {
    let htmlString: String
    let maxHeight: CGFloat?
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        let textView = NSTextView()
        
        textView.isEditable = false
        textView.isSelectable = true
        textView.backgroundColor = NSColor.clear
        textView.textContainerInset = NSSize(width: 0, height: 0)
        textView.textContainer?.lineFragmentPadding = 0
        
        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        
        if let maxHeight = maxHeight {
            scrollView.frame = NSRect(x: 0, y: 0, width: 0, height: maxHeight)
        }
        
        return scrollView
    }
    
    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        
        // Convert HTML to attributed string
        let attributedString = createAttributedString(from: htmlString)
        textView.textStorage?.setAttributedString(attributedString)
        
        // Adjust text view size to content
        let contentSize = textView.textStorage?.size() ?? NSSize.zero
        
        let height = max(contentSize.height + 20, 100) // Add padding and minimum height
        textView.frame = NSRect(x: 0, y: 0, width: scrollView.frame.width, height: height)
        
        // Update scroll view content size
        scrollView.documentView?.frame = NSRect(x: 0, y: 0, width: scrollView.frame.width, height: height)
    }
    
    private func createAttributedString(from htmlString: String) -> NSAttributedString {
        // Clean up common HTML entities and tags
        var cleanedString = htmlString
        
        // Replace common HTML entities
        cleanedString = cleanedString.replacingOccurrences(of: "&amp;", with: "&")
        cleanedString = cleanedString.replacingOccurrences(of: "&lt;", with: "<")
        cleanedString = cleanedString.replacingOccurrences(of: "&gt;", with: ">")
        cleanedString = cleanedString.replacingOccurrences(of: "&quot;", with: "\"")
        cleanedString = cleanedString.replacingOccurrences(of: "&#39;", with: "'")
        cleanedString = cleanedString.replacingOccurrences(of: "&nbsp;", with: " ")
        
        // Remove common HTML tags that might cause issues
        cleanedString = cleanedString.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        
        // Create attributed string with proper styling
        let attributedString = NSMutableAttributedString(string: cleanedString)
        
        // Apply paragraph style
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 2
        paragraphStyle.paragraphSpacing = 4
        
        let range = NSRange(location: 0, length: attributedString.length)
        attributedString.addAttribute(.paragraphStyle, value: paragraphStyle, range: range)
        
        // Apply font
        let font = NSFont.systemFont(ofSize: NSFont.systemFontSize)
        attributedString.addAttribute(.font, value: font, range: range)
        
        // Apply text color
        let textColor = NSColor.labelColor
        attributedString.addAttribute(.foregroundColor, value: textColor, range: range)
        
        return attributedString
    }
}

// MARK: - SwiftUI Text Extension

extension Text {
    init(htmlString: String) {
        // Clean HTML and create plain text
        var cleanedString = htmlString
        
        // Replace common HTML entities
        cleanedString = cleanedString.replacingOccurrences(of: "&amp;", with: "&")
        cleanedString = cleanedString.replacingOccurrences(of: "&lt;", with: "<")
        cleanedString = cleanedString.replacingOccurrences(of: "&gt;", with: ">")
        cleanedString = cleanedString.replacingOccurrences(of: "&quot;", with: "\"")
        cleanedString = cleanedString.replacingOccurrences(of: "&#39;", with: "'")
        cleanedString = cleanedString.replacingOccurrences(of: "&nbsp;", with: " ")
        
        // Remove HTML tags
        cleanedString = cleanedString.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        
        self.init(cleanedString)
    }
}

#Preview {
    VStack(spacing: 20) {
        Text("Plain Text")
            .font(.headline)
        
        HTMLTextView("<p>This is <strong>HTML</strong> content with <em>tags</em> and &amp; entities.</p>")
            .frame(height: 100)
            .border(Color.gray, width: 1)
        
        Text(htmlString: "<p>This is <strong>HTML</strong> content with <em>tags</em> and &amp; entities.</p>")
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
    }
    .padding()
}
