# Nim Templating Engine

A lightweight HTML templating engine built with the Nim programming language. This project provides a simple HTTP server with routing capabilities that serves dynamically rendered HTML content.

## Features

- Custom template rendering system with variable interpolation
- Support for loops using `{{each}}` directives
- Conditional content using `{{if}}` statements
- JSON data binding for dynamic content
- Simple HTTP server with routing capabilities
- Docker support for easy deployment

## Installation

### Prerequisites

- Nim compiler (v1.6.0 or higher recommended)
- Docker (optional, for containerized deployment)

### Local Setup

1. Clone the repository
```bash
git clone <repository-url>
cd testing-exe
```

2. Build and run the application
```bash
nim c -r main.nim
```

3. The server will start at http://localhost:5000

### Docker Setup

1. Build the Docker image
```bash
docker build -t nim-template-engine .
```

2. Run the container
```bash
docker run -p 5000:5000 nim-template-engine
```

## Template Syntax

The templating engine supports the following syntax:

- **Variables**: `{{variableName}}`
- **Loops**: 
  ```
  {{each items}}
    {{name}} - ${{price}}
  {{/each}}
  ```
- **Conditionals**: 
  ```
  {{if condition}}
    Conditional content
  {{/if}}
  ```

## Project Structure

```
testing-exe/
├── main.nim           # Server and routing implementation
├── templateEng.nim    # Template engine core
├── Dockerfile         # Docker configuration
├── src/
│   └── app/          # Template files (.enim)
│       ├── test.enim
│       └── template.enim
└── .build/
    └── static/       # Generated HTML output
```

## Available Routes

| Method | Route | Description |
|--------|-------|-------------|
| GET | `/hello` | Returns a simple "Hello, World!" text response |
| GET | `/test` | Renders the test template with example data |
| GET | `/user/{id}` | Dynamic route that displays the provided user ID |
| POST | `/post` | Accepts JSON data and returns it in the response |

## Example Usage

### Testing the `/test` route

Visit http://localhost:5000/test in your browser to see a rendered test template with example data.

### Testing the dynamic route

Visit http://localhost:5000/user/123 to see the user ID "123" displayed.

### Testing the POST endpoint

Send a POST request to http://localhost:5000/post with JSON data:

```bash
curl -X POST -H "Content-Type: application/json" -d '{"name":"Test","value":123}' http://localhost:5000/post
```

## Deployment

This project is configured for easy deployment on cloud platforms like Render.

1. Fork or clone the repository to your own GitHub account
2. Connect your GitHub repository to Render
3. Configure a new Web Service with the following settings:
   - Build Command: `docker build -t nim-template-engine .`
   - Start Command: `docker run -p $PORT:5000 nim-template-engine`

## License

[MIT License](LICENSE)
