FROM alpine:latest
RUN apk add --no-cache bash
CMD ["bash", "-c", "echo 'Hello!'"]
