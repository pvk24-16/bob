CFLAGS=-I../../api
LDFLAGS=-shared -fPIC -lGL

ifeq ($(shell uname -s | grep -o _NT),_NT)
OUT=simple.dll
else
OUT=simple.so
endif

$(OUT): simple.c
	$(CC) $(CFLAGS) $(LDFLAGS) -o $@ $<

clean:
	rm -f $(OUT)

.PHONY: clean
