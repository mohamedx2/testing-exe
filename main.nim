import strutils, net, json, tables
import asyncnet, asyncdispatch, async
import templateEng
# Define the structure for Request and Response
type
  Request = object
    methodName: string
    url: string
    body: string
    headers: Table[string, string]

  Response = object
    body: string
    status: int
    headers: Table[string, string]

# Type for a route handler
type
  RouteHandler = proc(req: Request): Response

# Store routes as a sequence of tuples
var routes: seq[(string, RouteHandler)] = @[]

# Function to register routes
proc route(path: string, handler: RouteHandler) =
  routes.add((path, handler))

# Function to handle a GET request
proc get(path: string, handler: RouteHandler) =
  route(path, handler)

# Function to handle a POST request
proc post(path: string, handler: RouteHandler) =
  route(path, handler)

# A simple handler function to test
proc helloHandler(req: Request): Response =
  result.body = "Hello, World!"
  result.status = 200
  result.headers = initTable[string, string]()
  result.headers["Content-Type"] = "text/plain"
proc testHandler(req: Request): Response =
  let data = %*{
    "title": "Test Template",
    "description": "This is a test template with dynamic content.",
    "items": [
      %*{"name": "Laptop", "price": 999.99},
      %*{"name": "Smartphone", "price": 499.99}
    ],
    "condition": true
  }
  let templatePath = "./src/app/test.enim"
  var templateContent: string = readTemplate(templatePath)
  echo renderTemplate(templateContent, data)
  result.body = renderTemplate(templateContent, data)
  result.status = 200
  result.headers = initTable[string, string]()
  result.headers["Content-Type"] =  "text/html"
  
# Improved POST handler with proper JSON parsing and error handling
proc postHandler(req: Request): Response =
  echo "Processing POST request..."  # Debug: Log post request processing start
  if req.body.len == 0:
    result.body = "Empty request body"
    result.status = 400
    result.headers = initTable[string, string]()
    result.headers["Content-Type"] = "text/plain"
    return result

  echo "Raw Body: ", req.body  # Debug: print raw body to check if it's correct

  try:
    var jsonData = parseJson(req.body)  # Attempt to parse the raw body
    echo "Parsed JSON: ", jsonData  # Debug: Log the parsed JSON
  except JsonParsingError as e:
    echo "Invalid JSON: ", e.msg  # Print error for debugging
    result.body = "Invalid JSON: " & e.msg
    result.status = 400
    result.headers = initTable[string, string]()
    result.headers["Content-Type"] = "application/json"
    return result

  result.body = "{\"received\": \"" & req.body.strip() & "\"}"  # JSON response
  result.status = 200
  result.headers = initTable[string, string]()
  result.headers["Content-Type"] = "application/json"

# A handler to simulate dynamic route handling
proc dynamicHandler(req: Request): Response =
  var urlParts = req.url.split("/")
  var userId = if urlParts.len > 2: urlParts[2] else: ""
  result.body = "User ID: " & userId
  result.status = 200
  result.headers = initTable[string, string]()
  result.headers["Content-Type"] = "text/plain"

# Function to parse the request data dynamically
proc parseRequestData(client: AsyncSocket): Future[Request] {.async.} =
  # Read the request line (method, url, version)
  let requestLine = await client.recvLine()
  echo "Request Line: ", requestLine  # Debug: show the request line

  if requestLine.strip() == "":
    echo "Received empty request line, returning default request."
    return Request(methodName: "", url: "", body: "", headers: initTable[string, string]())

  let reqLineParts = requestLine.split(" ")
  if reqLineParts.len < 2:
    echo "Malformed request line, returning default request: ", requestLine
    return Request(methodName: "", url: "", body: "", headers: initTable[string, string]())

  let methodName = reqLineParts[0]
  let url = reqLineParts[1]

  # Read headers (until we find a blank line indicating the end of headers)
  var headers = initTable[string, string]()
  var body = ""

  # Read headers line by line until a blank line is encountered
  while true:
    let headerLine = await client.recvLine()
    echo "Header Line: ", headerLine  # Debug: show header line
    if headerLine.strip() == "":
      break  # End of headers

    let headerParts = headerLine.split(":", maxsplit=2)
    if headerParts.len == 2:
      let headerName = headerParts[0].strip()
      let headerValue = headerParts[1].strip()
      headers[headerName] = headerValue
    else:
      echo "Skipping malformed header line: ", headerLine  # Log any malformed headers

  # Handle POST requests - read the body after headers
  if methodName == "POST" and headers.hasKey("Content-Length"):
    let contentLength = headers["Content-Length"].parseInt()
    echo "Content-Length: ", contentLength  # Debugging the content length
    if contentLength > 0:
      body = await client.recv(contentLength)
      echo "Body Received: ", body.strip()  # Show the body content

  # Return the request object with the parsed data
  result = Request(methodName: methodName, url: url, body: body.strip(), headers: headers)
  echo result

# Helper function to check if the URL matches a pattern with dynamic segments
proc matchRoute(url, pattern: string): bool =
  let urlParts = url.split("/")
  let patternParts = pattern.split("/")

  if urlParts.len != patternParts.len:
    return false

  for i in 0 ..< urlParts.len:
    if patternParts[i].startsWith("{") and patternParts[i].endsWith("}") :
      continue  # Skip comparison for dynamic segments
    elif urlParts[i] != patternParts[i]:
      return false

  return true


# Function to handle all incoming requests
proc handleRequest(client: AsyncSocket) {.async.} =
  try:
    let req = await parseRequestData(client)  # Await the Future result
    echo "Handling request: ", req.methodName, " ", req.url  # Log the request

    var found = false
    for route in routes:
      echo "Checking route pattern: ", route[0]  # Debug: Print pattern being checked
      if matchRoute(req.url, route[0]):
        echo "Matched route: ", route[0]  # Debug: Log when a match is found
        let response = route[1](req)
        await client.send("HTTP/1.1 " & $response.status & " OK\r\n")
        for key, value in response.headers.pairs:
          await client.send(key & ": " & value & "\r\n")
        await client.send("\r\n" & response.body & "\r\n")
        found = true
        break

    if not found:
      await client.send("HTTP/1.1 404 Not Found\r\n\r\nRoute not found.\r\n")
  except Exception as e:
    echo "Error: ", e.msg  # Log the error message
    await client.send("HTTP/1.1 500 Internal Server Error\r\n\r\nError handling request.\r\n")
  finally:
    client.close()  # Ensure connection is closed after handling
# The server accepts connections and calls the appropriate handler
proc runServer(port: int) {.async.} =
  let server = newAsyncSocket()
  server.bindAddr(Port(port))
  server.listen()

  # Log server start
  echo "Server is running at http://localhost:" & $port

  while true:
    let client = await server.accept()
    waitFor handleRequest(client)

# Register routes
get("/hello", helloHandler)
get("/test", testHandler)
get("/user/{id}", dynamicHandler)
post("/post", postHandler)  # Now using post instead of get for POST requests

# Start the server on port 5000
waitFor runServer(5000)