FROM golang:1.25-alpine AS build
WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download
COPY main.go operations.go sample.csv ./
RUN CGO_ENABLED=0 go build -trimpath -o /saldo-api .

FROM alpine:3.23
RUN adduser -D -H saldo
COPY --from=build /saldo-api /usr/local/bin/saldo-api
USER saldo
EXPOSE 8080
ENTRYPOINT ["/usr/local/bin/saldo-api"]
