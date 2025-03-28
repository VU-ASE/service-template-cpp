# Makefile in accordance with the docs on git management (to use in combination with meta)
.PHONY: build start clean test fetch-roverlib-c

BUILD_DIR=bin/
BINARY_NAME=SERVICE_NAME

# If not using VSCode's devcontainers, with docker installed you can run this command to
# build the service inside the container.
build-docker:
	docker build -t ase-service-c -f .devcontainer/Dockerfile .
	docker run -it --cap-add=SYS_PTRACE \
		--security-opt seccomp=unconfined \
		--privileged \
		--user=dev:dev \
		-v "`pwd`":/workspaces/work \
		-w /workspaces/work \
		ase-service-c bash -ic 'make build -C /workspaces/work'

# This target clones roverlib-c so that it can be compiled along side the service
fetch-roverlib-c:
	@if [ ! -d "lib" ] || [ -z "$$(ls -A lib 2>/dev/null)" ]; then \
		echo "roverlib-c directory doesn't exist or is empty. Cloning into lib..."; \
		git clone https://github.com/VU-ASE/roverlib-c.git lib; \
	elif [ ! -d "lib/.git" ]; then \
		echo "directory lib exists but is not a git repository. Recloning..."; \
		rm -rf lib; \
		git clone https://github.com/VU-ASE/roverlib-c.git lib; \
	else \
		echo "getting latest roverlib-c"; \
		cd lib && git pull; \
	fi

# The following two targets change a single line in a header file because of an annoying bug
# where the system installation of hashtable for C++ took priority over the locally installed one
edit-headers:
	@echo "> editing ./lib/include/roverlib/bootinfo.h"
	@echo "     changing line: '#include <hashtable.h>'"
	@echo "     to:            '#include \"/usr/local/include/hashtable.h\"'"
	@sed -i "s/#include <hashtable.h>/#include \"\/usr\/local\/include\/hashtable.h\"/" ./lib/include/roverlib/bootinfo.h

	@echo "> editing ./lib/include/roverlib/configuration.h"
	@echo "     changing line: '#include <hashtable.h>'"
	@echo "     to:            '#include \"/usr/local/include/hashtable.h\"'"
	@sed -i "s/#include <hashtable.h>/#include \"\/usr\/local\/include\/hashtable.h\"/" ./lib/include/roverlib/configuration.h

build: fetch-roverlib-c edit-headers
	@mkdir -p build
	@mkdir -p build/obj
	@mkdir -p build/obj/rovercom/outputs
	@mkdir -p build/obj/rovercom/tuning
	@mkdir -p $(BUILD_DIR)

	# Compile all .c files to .o files
	@for file in ./lib/src/*.c; do \
		basename=$$(basename $$file); \
		gcc -c -fPIC -o ./build/obj/$${basename%.c}.o $$file \
		-I/usr/include/cjson -I./lib/include -g; \
	done

	# Compile rovercom/outputs/*.c files
	@for file in ./lib/src/rovercom/outputs/*.c; do \
		basename=$$(basename $$file); \
		gcc -c -fPIC -o ./build/obj/rovercom/outputs/$${basename%.c}.o $$file \
		-I/usr/include/cjson -I./lib/include -g; \
	done

	# Compile rovercom/tuning/*.c files
	@for file in ./lib/src/rovercom/tuning/*.c; do \
		basename=$$(basename $$file); \
		gcc -c -fPIC -o ./build/obj/rovercom/tuning/$${basename%.c}.o $$file \
		-I/usr/include/cjson -I./lib/include -g; \
	done

	# Create static library from all .o files
	@ar rcs ./build/librover.a ./build/obj/*.o ./build/obj/rovercom/outputs/*.o ./build/obj/rovercom/tuning/*.o

	# Compile the final C++ binary
	@g++ -o $(BUILD_DIR)$(BINARY_NAME) \
		src/*.cpp ./build/librover.a -lcjson -lzmq -lprotobuf-c -lhashtable -llist \
		-I/usr/include/cjson -I./lib/include -g

start: build
	@echo "starting ${BINARY_NAME}"
	./${BUILD_DIR}${BINARY_NAME} 

clean:
	@echo "Cleaning all targets for ${BINARY_NAME}"
	rm -rf $(BUILD_DIR)
	rm -rf build

test: 
	@echo "No tests configured"
