import os, strutils, json

# Function to read the template file with error handling
proc readTemplate(templatePath: string): string =
  if fileExists(templatePath):
    result = readFile(templatePath)
  else:
    raise newException(OSError, "Template file not found at path: " & templatePath)

# Basic function to evaluate simple arithmetic expressions
proc evalNimExpr(expr: string): string =
  try:
    let tokens = expr.splitWhitespace()
    if tokens.len != 3:
      return "Invalid expression"
    
    let left = parseFloat(tokens[0])
    let right = parseFloat(tokens[2])
    let operator = tokens[1]
    var evaluationResult: float
    
    case operator
    of "+": evaluationResult = left + right
    of "-": evaluationResult = left - right
    of "*": evaluationResult = left * right
    of "/":
      if right == 0:
        return "Division by zero"
      evaluationResult = left / right
    else:
      return "Unsupported operator"
    
    return $evaluationResult
  except:
    return "Error evaluating expression"

# Function to replace placeholders with data and evaluate Nim expressions, with iteration support
proc renderTemplate(templateContent: string, data: JsonNode): string =
  var renderedTemplate: string = templateContent
  let startDelim = "{{"
  let endDelim = "}}"
  var pos = 0

  while pos < renderedTemplate.len:
    let i = renderedTemplate.find(startDelim, pos)
    if i == -1: break
    let j = renderedTemplate.find(endDelim, i + startDelim.len)
    if j == -1: break
    
    let placeholder = renderedTemplate[i + startDelim.len ..< j].strip()

    if placeholder.startsWith("each"):
      let eachStart = "{{each "
      let eachEnd = "{{/each}}"
      
      let startIdx = renderedTemplate.find(eachStart, pos)
      if startIdx == -1: break
      let endIdx = renderedTemplate.find(eachEnd, startIdx)
      if endIdx == -1: break
      
      let collectionName = renderedTemplate[startIdx + eachStart.len ..< renderedTemplate.find("}}", startIdx)].strip()
      let blockContent = renderedTemplate[startIdx + eachStart.len + collectionName.len + 3 ..< endIdx]

      if data.hasKey(collectionName) and data[collectionName].kind == JArray:
        let collection = data[collectionName]
        var renderedBlock = ""
        
        for item in collection:
          var tempBlock = blockContent
          for key, val in pairs(item):
    # Try to handle different types of values
            let valueStr = 
              case val.kind
              of JInt, JFloat:
                # If it's a numeric type (integer or float), we convert it to string
                $val
              of JString:
                # If it's a string, directly use it
                val.getStr()
              else:
                # Handle other types if necessary (e.g., Booleans, null, etc.)
                "undefined"
              
            # Replace placeholder in the block content
            tempBlock = tempBlock.replace("{{" & key & "}}", valueStr)
            
          renderedBlock &= tempBlock

                  
        renderedTemplate = renderedTemplate[0 ..< startIdx] & renderedBlock & renderedTemplate[endIdx + eachEnd.len .. ^1]
        
        # Move `pos` to just after the rendered `each` block
        pos = startIdx + renderedBlock.len
      else:
        pos = endIdx + eachEnd.len  # Skip past `each` block if collection is invalid or empty

    elif placeholder.startsWith("if"):
      let ifStart = "{{if "
      let ifEnd = "{{/if}}"
      
      let startIdx = renderedTemplate.find(ifStart, pos)
      if startIdx == -1: break
      let endIdx = renderedTemplate.find(ifEnd, startIdx)
      if endIdx == -1: break
      
      let conditionKey = renderedTemplate[startIdx + ifStart.len ..< renderedTemplate.find("}}", startIdx)].strip()
      let blockContent = renderedTemplate[startIdx + ifStart.len + conditionKey.len + 3 ..< endIdx]

      if data.hasKey(conditionKey) and data[conditionKey].getBool():  # Check if condition is true
        renderedTemplate = renderedTemplate[0 ..< startIdx] & blockContent & renderedTemplate[endIdx + ifEnd.len .. ^1]
        pos = startIdx + blockContent.len  # Move `pos` to just after the rendered `if` block
      else:
        renderedTemplate = renderedTemplate[0 ..< startIdx] & renderedTemplate[endIdx + ifEnd.len .. ^1]
        pos = startIdx  # Move `pos` to after the `if` block, skipping the content if condition is false

    else:
      var replacement = placeholder
      if data.hasKey(placeholder):
        replacement = data[placeholder].getStr()
      renderedTemplate = renderedTemplate[0 ..< i] & replacement & renderedTemplate[j + endDelim.len .. ^1]
      pos = i + replacement.len  # Update `pos` to just after the replacement

  return renderedTemplate

# Function to render a specific .enim file in the src/app directory
proc renderFile(fileName: string, data: JsonNode = %*{}) =
  var templatePath = "./src/app/" & fileName
  if not templatePath.endsWith(".enim"):
    templatePath &= ".enim"
  
  # Try reading the template from the file
  try:
    let templateContent = readTemplate(templatePath)
    
    # Render the template with the provided data
    let renderedHtml = renderTemplate(templateContent, data)

    # Ensure the output directory exists
    let outputDir = ".build/static"
    if not dirExists(outputDir):
      createDir(outputDir)

    # Make sure the output file has the .html extension
    var outputPath = outputDir / fileName
    if not outputPath.endsWith(".html"):
      outputPath &= ".html"

    # Write the rendered HTML content to the file
    writeFile(outputPath, renderedHtml)
    echo "HTML file generated at: ", outputPath
  except OSError as e:
    echo "Error: ", e.msg
  except Exception as e:
    echo "Unexpected error: ", e.msg

# Export functions
export renderFile, renderTemplate, readTemplate
