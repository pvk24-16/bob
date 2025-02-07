CFLAGS= -I../../api
LDFLAGS=-shared -fPIC

simple.so: simple.c
	$(CC) $(CFLAGS) $(LDFLAGS) -o $@ $<

clean:
	rm -f *.so

.PHONY: clean
