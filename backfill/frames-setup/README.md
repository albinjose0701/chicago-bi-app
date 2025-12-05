# To build and run
docker build -t video-streaming:latest .
docker run -d -p 3000:3000 -v "$(pwd)/video:/media" video-streaming:latest
