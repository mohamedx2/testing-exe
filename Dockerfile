FROM ubuntu:latest
RUN apt-get update && apt-get install -y wine
COPY main.exe /app/
WORKDIR /app
CMD ["wine", "main.exe"]
