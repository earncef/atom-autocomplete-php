fuzzaldrin = require 'fuzzaldrin'
minimatch = require 'minimatch'
exec = require "child_process"

internals = require "./php-internals.coffee"
AbstractProvider = require "./php-abstract-provider"
{$, $$, Range} = require 'atom'

module.exports =
# Autocompletion for class names
class ClassProvider extends AbstractProvider
  getSuggestions: ({editor, bufferPosition, scopeDescriptor, prefix}) ->
    # "new" keyword or word starting with capital letter
    @regex = /\b(new \w*[a-zA-Z_\\]\w*)|([A-Z]([a-zA-Z_])*)\b/g

    selection = editor.getSelection()
    prefix = @getPrefix(editor, bufferPosition)
    return unless prefix.length

    @classes = internals.classes()

    suggestions = @findSuggestionsForPrefix prefix
    return unless suggestions.length
    return suggestions

  confirm: (suggestion) ->
    selection = @editor.getSelection()
    startPosition = selection.getBufferRange().start
    buffer = @editor.getBuffer()

    # if some args (even empty) => instanciation
    if suggestion.data?.args?
      @showSnippet(suggestion)

    # Static methods on classes
    else
      cursorPosition = @editor.getCursorBufferPosition()
      buffer.delete Range.fromPointWithDelta(cursorPosition, 0, -suggestion.prefix.length)
      @editor.insertText suggestion.word + "::"

    return false # Don't fall back to the default behavior

  findSuggestionsForPrefix: (prefix) ->
    # Get rid of the leading "new" keyword
    instanciation = false
    if prefix.indexOf("new \\") != -1
      instanciation = true
      prefix = prefix.replace /^new \\/, ''
    else if prefix.indexOf("new ") != -1
      instanciation = true
      prefix = prefix.replace /^new /, ''

    # Filter the words using fuzzaldrin
    words = fuzzaldrin.filter @classes.names, prefix

    # Builds suggestions for the words
    suggestions = []
    for word in words when word isnt prefix
      # Just print classes with constructors with "new"
      if instanciation and @classes.methods[word].constructor.has
        params = @classes.methods[word].constructor.args.join(',')
        suggestions.push
          text: word,
          snippet: @getFunctionSnippet(word, @classes.methods[word].constructor.args),
#          rightLabel: "(#{params})"

      # Not instanciation => not printing constructor params
      else if not instanciation
        suggestions.push {word: word, prefix: prefix}

    return suggestions
