//
//  UXCodeTextViewRepresentable.swift
//  CodeEditor
//
//  Created by Helge Heß.
//  Copyright © 2021 ZeeZide GmbH. All rights reserved.
//

import SwiftUI

#if os(macOS)
  typealias UXViewRepresentable = NSViewRepresentable
#else
  typealias UXViewRepresentable = UIViewRepresentable
#endif

/**
 * Move the gritty details our of the main representable.
 */
struct UXCodeTextViewRepresentable : UXViewRepresentable {
  
  /**
   * Configures a CodeEditor View with the given parameters.
   *
   * - Parameters:
   *   - source:   A binding to a String that holds the source code to be edited
   *               (or displayed).
   *   - language: Optionally set a language (e.g. `.swift`), otherwise
   *               Highlight.js will attempt to detect the language.
   *   - theme:    The name of the theme to use.
   *   - fontSize: On macOS this Binding can be used to persist the size of
   *               the font in use. At runtime this is combined with the
   *               theme to produce the full font information.
   *   - flags:    Configure whether the text is editable and/or selectable.
   */
  public init(source   : Binding<String>,
              language : CodeEditor.Language?,
              theme    : CodeEditor.ThemeName,
              fontSize : Binding<CGFloat>?,
              flags    : CodeEditor.Flags)
  {
    self.source    = source
    self.fontSize  = fontSize
    self.language  = language
    self.themeName = theme
    self.flags     = flags
  }
    
  private var source    : Binding<String>
  private var fontSize  : Binding<CGFloat>?
  private let language  : CodeEditor.Language?
  private let themeName : CodeEditor.ThemeName
  private let flags     : CodeEditor.Flags
  private let inset     = CGSize(width: 8, height: 8)
    
  public final class Coordinator: NSObject, UXCodeTextViewDelegate {
    
    var parent : UXCodeTextViewRepresentable
    
    var fontSize : CGFloat? {
      set { if let value = newValue { parent.fontSize?.wrappedValue = value } }
      get { parent.fontSize?.wrappedValue }
    }
    
    init(_ parent: UXCodeTextViewRepresentable) {
      self.parent = parent
    }
    
    public func textDidChange(_ notification: Notification) {
      guard let textView = notification.object as? UXTextView else {
        assertionFailure("unexpected notification object")
        return
      }
      parent.source.wrappedValue = textView.string
    }
    
    var allowCopy: Bool {
      return parent.flags.contains(.selectable)
          || parent.flags.contains(.editable)
    }
  }
    
  public func makeCoordinator() -> Coordinator {
    return Coordinator(self)
  }
  
  private func updateTextView(_ textView: UXCodeTextView) {
    if let binding = fontSize {
      textView.applyNewTheme(themeName, andFontSize: binding.wrappedValue)
    }
    else {
      textView.applyNewTheme(themeName)
    }
    textView.language = language
    
    if source.wrappedValue != textView.string {
      if let textStorage = textView.codeTextStorage {
        textStorage.replaceCharacters(in   : NSMakeRange(0, textStorage.length),
                                      with : source.wrappedValue)
      }
      else {
        assertionFailure("no text storage?")
        textView.string = source.wrappedValue
      }
    }
    
    textView.isEditable   = flags.contains(.editable)
    textView.isSelectable = flags.contains(.selectable)
  }

  #if os(macOS)
    public func makeNSView(context: Context) -> NSScrollView {
      let textView = UXCodeTextView()
      textView.autoresizingMask   = [ .width, .height ]
      textView.delegate           = context.coordinator
      textView.allowsUndo         = true
      textView.textContainerInset = inset

      let scrollView = NSScrollView()
      scrollView.hasVerticalScroller = true
      scrollView.documentView = textView
      
      updateTextView(textView)
      return scrollView
    }
    
    public func updateNSView(_ scrollView: NSScrollView, context: Context) {
      guard let textView = scrollView.documentView as? UXCodeTextView else {
        assertionFailure("unexpected text view")
        return
      }
      if textView.delegate !== context.coordinator {
        textView.delegate = context.coordinator
      }
      updateTextView(textView)
    }
  #else // iOS etc
    public func makeUIView(context: Context) -> UITextView {
      let textView = UXCodeTextView()
      textView.autoresizingMask   = [ .flexibleWidth, .flexibleHeight ]
      textView.delegate           = context.coordinator
      textView.textContainerInset = UIEdgeInsets(
        top    : inset.height, left  : inset.width,
        bottom : inset.height, right : inset.width
      )
      
      updateTextView(textView)
      return textView
    }
    
    public func updateUIView(_ textView: UITextView, context: Context) {
      guard let textView = textView as? UXCodeTextView else {
        assertionFailure("unexpected text view")
        return
      }
      if textView.delegate !== context.coordinator {
        textView.delegate = context.coordinator
      }
      updateTextView(textView)
    }
  #endif // iOS
}

struct UXCodeTextViewRepresentable_Previews: PreviewProvider {
  
  static var previews: some View {
    
    UXCodeTextViewRepresentable(source   : .constant("let a = 5"),
                                language : nil,
                                theme    : .pojoaque,
                                fontSize : nil,
                                flags    : [ .selectable ])
      .frame(width: 200, height: 100)
    
    UXCodeTextViewRepresentable(source: .constant("let a = 5"),
                                language : .swift,
                                theme    : .pojoaque,
                                fontSize : nil,
                                flags    : [ .selectable ])
      .frame(width: 200, height: 100)
    
    UXCodeTextViewRepresentable(
      source: .constant(
        #"""
        The quadratic formula is $-b \pm \sqrt{b^2 - 4ac} \over 2a$
        \bye
        """#
      ),
      language: .tex,
      theme    : .pojoaque,
      fontSize : nil,
      flags    : [ .selectable ]
    )
    .frame(width: 540, height: 200)
  }
}