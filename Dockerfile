# Start with a base Linux image with Nim pre-installed or install Nim yourself
FROM nimlang/nim:alpine

# Set the working directory in the container
WORKDIR /app

# Copy the project files into the container
COPY . .

# Compile the Nim project to a Linux binary
RUN nim c -d:release main.nim

# Command to run the compiled binary
CMD ["./main"]
