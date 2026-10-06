/*
 * mouse-wheel-debounce - drop mouse wheel encoder chatter.
 *
 * Reads and writes the raw `struct input_event` stream that interception-tools
 * passes between `intercept` and `uinput`. Sitting below libinput means the
 * events dropped here are events the compositor never sees, and it means the
 * decision can be made on the kernel's own event timestamps.
 *
 * A worn wheel encoder reports one detent transition more than once. Measured
 * on the mouse this was written for, every spurious tick landed within a few
 * milliseconds of the tick it belonged to, while a genuine change of direction
 * never came closer than 120 ms. Three rules follow, each with a window:
 *
 *   --repeat-window   a tick in the established direction arriving this soon
 *                     after the previous one is the same detent reported
 *                     twice.
 *   --reverse-window  a tick against the established direction arriving this
 *                     soon after the previous one cannot be a reversal, so it
 *                     is chatter. Beyond that it is *held* for the window: if
 *                     the next tick goes back the way we came, it was chatter
 *                     after all and is dropped; otherwise it was a real
 *                     reversal and is released.
 *
 * The hold is what the timer in main() is for, and it is why a reversal is
 * only ever delayed by one window: a bounce is distinguishable from a reversal
 * solely by what comes after it. Anything not recognized as a wheel tick is
 * passed through untouched, so a report whose ticks were all dropped still
 * ends in the bare SYN_REPORT that closed it. An empty report is a no-op.
 *
 * Both REL_WHEEL and REL_WHEEL_HI_RES are filtered. Devices reporting both
 * send them as a pair with identical timestamps and the same sign, so they are
 * decided together - the twin of a held tick joins it instead of starting a
 * second decision that could disagree.
 */

#define _POSIX_C_SOURCE 200809L

#include <errno.h>
#include <poll.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/time.h>
#include <time.h>
#include <unistd.h>

#include <linux/input.h>

/* A tick and its HI_RES twin, plus room for a repeat of either. */
#define MAX_PENDING 4

#define NS_PER_MS 1000000L

static long reverse_window_ms = 50;
static long repeat_window_ms = 8;

/* Direction of the last tick that was let through, 0 until the first one. */
static int established;
static bool have_last;
static struct timeval last_emit;

/*
 * The tick decided most recently, emitted or not, so that the other wheel
 * code describing the same notch follows it instead of being judged on its
 * own. Without this the repeat window would eat every HI_RES record, since
 * the twin of an emitted tick arrives with the identical timestamp.
 */
static bool have_decision;
static struct timeval decision_time;
static bool decision_emitted;

/* A tick whose direction is still undecided, held until its window expires. */
static struct input_event pending[MAX_PENDING];
static size_t pending_len;
static int pending_dir;
static struct timeval pending_time;
static struct timespec pending_deadline;

static void put(const struct input_event *ev)
{
	const char *p = (const char *)ev;
	size_t left = sizeof *ev;

	while (left > 0) {
		ssize_t n = write(STDOUT_FILENO, p, left);

		if (n < 0) {
			if (errno == EINTR)
				continue;
			/* The rest of the pipeline is gone. */
			exit(EXIT_FAILURE);
		}
		p += n;
		left -= (size_t)n;
	}
}

static long elapsed_ms(const struct timeval *now, const struct timeval *then)
{
	return (long)(now->tv_sec - then->tv_sec) * 1000
	     + (long)(now->tv_usec - then->tv_usec) / 1000;
}

/* Two wheel events describing one notch carry the kernel's instant verbatim. */
static bool same_instant(const struct input_event *a, const struct timeval *b)
{
	return a->time.tv_sec == b->tv_sec && a->time.tv_usec == b->tv_usec;
}

static void decide(const struct input_event *ev, bool emitted)
{
	have_decision = true;
	decision_time = ev->time;
	decision_emitted = emitted;

	if (emitted)
		put(ev);
}

/* Release a held tick: it was a genuine reversal after all. */
static void flush_pending(void)
{
	struct input_event syn;

	if (pending_len == 0)
		return;

	syn = (struct input_event){
		.time = pending[pending_len - 1].time,
		.type = EV_SYN,
		.code = SYN_REPORT,
		.value = 0,
	};

	for (size_t i = 0; i < pending_len; i++)
		put(&pending[i]);

	/*
	 * A report only takes effect once it ends, and the report this tick
	 * came from is long gone, so it needs one of its own.
	 */
	put(&syn);

	established = pending_dir;
	last_emit = pending_time;
	have_last = true;
	pending_len = 0;
}

static void handle_tick(const struct input_event *ev)
{
	int dir = ev->value > 0 ? 1 : (ev->value < 0 ? -1 : 0);

	if (dir == 0) {
		put(ev);
		return;
	}

	/*
	 * The HI_RES twin of a tick already being held: same instant, same
	 * direction, so it shares that decision rather than making its own.
	 */
	if (pending_len > 0 && dir == pending_dir && same_instant(ev, &pending_time)) {
		if (pending_len < MAX_PENDING)
			pending[pending_len++] = *ev;
		return;
	}

	/*
	 * The twin of the tick decided a moment ago, which shares its fate -
	 * including a drop, so that the repeat window never sees it as a notch
	 * of its own.
	 */
	if (have_decision && same_instant(ev, &decision_time)) {
		if (!decision_emitted)
			return;
		last_emit = ev->time;
		put(ev);
		return;
	}

	/* What came after a held tick is what decides what it was. */
	if (pending_len > 0) {
		if (dir == -pending_dir
		    && elapsed_ms(&ev->time, &pending_time) <= reverse_window_ms)
			pending_len = 0;	/* it doubled back: chatter */
		else
			flush_pending();	/* it did not: a reversal */
	}

	if (!have_last) {
		established = dir;
		last_emit = ev->time;
		have_last = true;
		decide(ev, true);
		return;
	}

	if (dir == established) {
		if (elapsed_ms(&ev->time, &last_emit) < repeat_window_ms) {
			decide(ev, false);	/* one detent, reported twice */
			return;
		}
		last_emit = ev->time;
		decide(ev, true);
		return;
	}

	if (elapsed_ms(&ev->time, &last_emit) <= reverse_window_ms) {
		decide(ev, false);		/* nothing reverses this fast */
		return;
	}

	pending[0] = *ev;
	pending_len = 1;
	pending_dir = dir;
	pending_time = ev->time;

	/*
	 * Measured from the tick itself, not from now, so the hold ends at the
	 * same instant in event time that the elapsed_ms() checks above use.
	 * Event timestamps are CLOCK_REALTIME, which is what poll_timeout_ms()
	 * counts down from.
	 */
	pending_deadline.tv_sec = pending_time.tv_sec + reverse_window_ms / 1000;
	pending_deadline.tv_nsec = (long)pending_time.tv_usec * 1000
				 + (reverse_window_ms % 1000) * NS_PER_MS;
	if (pending_deadline.tv_nsec >= 1000000000L) {
		pending_deadline.tv_sec += 1;
		pending_deadline.tv_nsec -= 1000000000L;
	}
}

/* Milliseconds until a held tick must be released, -1 if nothing is held. */
static int poll_timeout_ms(void)
{
	struct timespec now;
	long ms;

	if (pending_len == 0)
		return -1;

	clock_gettime(CLOCK_REALTIME, &now);
	ms = (long)(pending_deadline.tv_sec - now.tv_sec) * 1000
	   + (long)(pending_deadline.tv_nsec - now.tv_nsec) / NS_PER_MS;

	if (ms < 0)
		return 0;
	if (ms > 1000)
		return 1000;
	return (int)ms;
}

static void usage(const char *argv0)
{
	fprintf(stderr, "usage: %s [--repeat-window MS] [--reverse-window MS]\n",
		argv0);
}

int main(int argc, char **argv)
{
	unsigned char buf[sizeof(struct input_event) * 64];
	size_t have = 0;

	for (int i = 1; i < argc; i++) {
		long *window;
		char *end;
		long value;

		if (strcmp(argv[i], "--repeat-window") == 0)
			window = &repeat_window_ms;
		else if (strcmp(argv[i], "--reverse-window") == 0)
			window = &reverse_window_ms;
		else {
			usage(argv[0]);
			return 2;
		}

		if (++i >= argc) {
			usage(argv[0]);
			return 2;
		}

		errno = 0;
		value = strtol(argv[i], &end, 10);
		if (errno != 0 || *end != '\0' || value < 1) {
			fprintf(stderr, "%s: %s is not a positive number of ms\n",
				argv[0], argv[i]);
			return 2;
		}
		*window = value;
	}

	for (;;) {
		struct pollfd pfd = { .fd = STDIN_FILENO, .events = POLLIN };
		size_t off = 0;
		ssize_t n;
		int ready = poll(&pfd, 1, poll_timeout_ms());

		if (ready < 0) {
			if (errno == EINTR)
				continue;
			perror("mouse-wheel-debounce: poll");
			return 1;
		}

		if (ready == 0) {
			flush_pending();	/* the window ran out */
			continue;
		}

		n = read(STDIN_FILENO, buf + have, sizeof buf - have);
		if (n < 0) {
			if (errno == EINTR)
				continue;
			perror("mouse-wheel-debounce: read");
			return 1;
		}
		if (n == 0)
			break;

		have += (size_t)n;

		while (have - off >= sizeof(struct input_event)) {
			struct input_event ev;

			memcpy(&ev, buf + off, sizeof ev);
			off += sizeof ev;

			if (ev.type == EV_REL
			    && (ev.code == REL_WHEEL
				|| ev.code == REL_WHEEL_HI_RES))
				handle_tick(&ev);
			else
				put(&ev);
		}

		memmove(buf, buf + off, have - off);
		have -= off;
	}

	flush_pending();
	return 0;
}
