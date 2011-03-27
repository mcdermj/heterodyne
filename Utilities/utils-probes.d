provider buffers {
	probe ringbuffer__put(char *name, long used, long free);
	probe ringbuffer__get(char *name, long used, long free);
    probe blockbuffer__put(long used, long free);
    probe blockbuffer__get(long used, long free);
};