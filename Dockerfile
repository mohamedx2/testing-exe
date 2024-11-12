# Use a Windows base image
FROM mcr.microsoft.com/windows/servercore:ltsc2019

# Set the working directory to the main directory
WORKDIR /app

# Copy the main.exe file from your local directory to the container
COPY main.exe .

# Expose the port your server listens on (adjust if necessary)
EXPOSE 5000

# Run the main.exe file when the container starts
CMD ["main.exe"]
