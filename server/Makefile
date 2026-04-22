.PHONY: proto build run test clean docker-up docker-down migrate-up migrate-down

PROTO_DIR := ../proto
PROTO_OUT := ./proto

proto:
	mkdir -p $(PROTO_OUT)/auth $(PROTO_OUT)/transaction $(PROTO_OUT)/sync $(PROTO_OUT)/family $(PROTO_OUT)/account $(PROTO_OUT)/budget $(PROTO_OUT)/notify $(PROTO_OUT)/loan $(PROTO_OUT)/investment
	protoc -I$(PROTO_DIR) \
		--go_out=$(PROTO_OUT)/auth --go_opt=paths=source_relative \
		--go-grpc_out=$(PROTO_OUT)/auth --go-grpc_opt=paths=source_relative \
		$(PROTO_DIR)/auth.proto
	protoc -I$(PROTO_DIR) \
		--go_out=$(PROTO_OUT)/transaction --go_opt=paths=source_relative \
		--go-grpc_out=$(PROTO_OUT)/transaction --go-grpc_opt=paths=source_relative \
		$(PROTO_DIR)/transaction.proto
	protoc -I$(PROTO_DIR) \
		--go_out=$(PROTO_OUT)/sync --go_opt=paths=source_relative \
		--go-grpc_out=$(PROTO_OUT)/sync --go-grpc_opt=paths=source_relative \
		$(PROTO_DIR)/sync.proto
	protoc -I$(PROTO_DIR) \
		--go_out=$(PROTO_OUT)/family --go_opt=paths=source_relative \
		--go-grpc_out=$(PROTO_OUT)/family --go-grpc_opt=paths=source_relative \
		$(PROTO_DIR)/family.proto
	protoc -I$(PROTO_DIR) \
		--go_out=$(PROTO_OUT)/account --go_opt=paths=source_relative \
		--go-grpc_out=$(PROTO_OUT)/account --go-grpc_opt=paths=source_relative \
		$(PROTO_DIR)/account.proto
	protoc -I$(PROTO_DIR) \
		--go_out=$(PROTO_OUT)/budget --go_opt=paths=source_relative \
		--go-grpc_out=$(PROTO_OUT)/budget --go-grpc_opt=paths=source_relative \
		$(PROTO_DIR)/budget.proto
	protoc -I$(PROTO_DIR) \
		--go_out=$(PROTO_OUT)/notify --go_opt=paths=source_relative \
		--go-grpc_out=$(PROTO_OUT)/notify --go-grpc_opt=paths=source_relative \
		$(PROTO_DIR)/notify.proto
	protoc -I$(PROTO_DIR) \
		--go_out=$(PROTO_OUT)/loan --go_opt=paths=source_relative \
		--go-grpc_out=$(PROTO_OUT)/loan --go-grpc_opt=paths=source_relative \
		$(PROTO_DIR)/loan.proto
	protoc -I$(PROTO_DIR) \
		--go_out=$(PROTO_OUT)/investment --go_opt=paths=source_relative \
		--go-grpc_out=$(PROTO_OUT)/investment --go-grpc_opt=paths=source_relative \
		$(PROTO_DIR)/investment.proto

sqlc:
	sqlc generate

build:
	go build -o bin/server ./cmd/server

run: build
	./bin/server

test:
	go test ./...

clean:
	rm -rf bin/

docker-up:
	cd .. && docker-compose up -d --build

docker-down:
	cd .. && docker-compose down

migrate-up:
	migrate -path migrations -database "postgres://familyledger:familyledger@localhost:5432/familyledger?sslmode=disable" up

migrate-down:
	migrate -path migrations -database "postgres://familyledger:familyledger@localhost:5432/familyledger?sslmode=disable" down
