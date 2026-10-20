#include <errno.h>
#include <fcntl.h>
#include <linux/uinput.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#define SCREEN_W 800
#define SCREEN_H 1280

static int output_fd;

static void emit(int type, int code, int value) {
    struct input_event event;

    memset(&event, 0, sizeof(event));
    event.type = type;
    event.code = code;
    event.value = value;
    if (write(output_fd, &event, sizeof(event)) < 0) {
        fprintf(stderr, "write: %s\n", strerror(errno));
        exit(1);
    }
}

static void sync_report(void) {
    emit(EV_SYN, SYN_REPORT, 0);
}

static void touch_down(int x, int y) {
    emit(EV_ABS, ABS_MT_SLOT, 0);
    emit(EV_ABS, ABS_MT_TRACKING_ID, 1);
    emit(EV_KEY, BTN_TOUCH, 1);
    emit(EV_ABS, ABS_MT_POSITION_X, x);
    emit(EV_ABS, ABS_MT_POSITION_Y, y);
    emit(EV_ABS, ABS_X, x);
    emit(EV_ABS, ABS_Y, y);
    sync_report();
}

static void touch_move(int x, int y) {
    emit(EV_ABS, ABS_MT_SLOT, 0);
    emit(EV_ABS, ABS_MT_POSITION_X, x);
    emit(EV_ABS, ABS_MT_POSITION_Y, y);
    emit(EV_ABS, ABS_X, x);
    emit(EV_ABS, ABS_Y, y);
    sync_report();
}

static void touch_up(void) {
    emit(EV_ABS, ABS_MT_SLOT, 0);
    emit(EV_ABS, ABS_MT_TRACKING_ID, -1);
    emit(EV_KEY, BTN_TOUCH, 0);
    sync_report();
}

static void setup_device(void) {
    struct uinput_abs_setup x = {
        .code = ABS_X,
        .absinfo = {.minimum = 0, .maximum = SCREEN_W},
    };
    struct uinput_abs_setup y = {
        .code = ABS_Y,
        .absinfo = {.minimum = 0, .maximum = SCREEN_H},
    };
    struct uinput_abs_setup mt_x = {
        .code = ABS_MT_POSITION_X,
        .absinfo = {.minimum = 0, .maximum = SCREEN_W},
    };
    struct uinput_abs_setup mt_y = {
        .code = ABS_MT_POSITION_Y,
        .absinfo = {.minimum = 0, .maximum = SCREEN_H},
    };
    struct uinput_abs_setup slot = {
        .code = ABS_MT_SLOT,
        .absinfo = {.minimum = 0, .maximum = 9},
    };
    struct uinput_abs_setup tracking_id = {
        .code = ABS_MT_TRACKING_ID,
        .absinfo = {.minimum = 0, .maximum = 65535},
    };
    struct uinput_setup setup;

    output_fd = open("/dev/uinput", O_WRONLY | O_NONBLOCK);
    if (output_fd < 0) {
        fprintf(stderr, "open /dev/uinput: %s\n", strerror(errno));
        exit(1);
    }

    ioctl(output_fd, UI_SET_EVBIT, EV_KEY);
    ioctl(output_fd, UI_SET_KEYBIT, BTN_TOUCH);
    ioctl(output_fd, UI_SET_EVBIT, EV_ABS);
    ioctl(output_fd, UI_SET_ABSBIT, ABS_MT_SLOT);
    ioctl(output_fd, UI_SET_ABSBIT, ABS_MT_TRACKING_ID);
    ioctl(output_fd, UI_SET_ABSBIT, ABS_MT_POSITION_X);
    ioctl(output_fd, UI_SET_ABSBIT, ABS_MT_POSITION_Y);
    ioctl(output_fd, UI_SET_ABSBIT, ABS_X);
    ioctl(output_fd, UI_SET_ABSBIT, ABS_Y);
    ioctl(output_fd, UI_SET_PROPBIT, INPUT_PROP_DIRECT);

    memset(&setup, 0, sizeof(setup));
    setup.id.bustype = BUS_VIRTUAL;
    setup.id.vendor = 0x1209;
    setup.id.product = 0x0004;
    strcpy(setup.name, "Prime4 Research Touch");
    ioctl(output_fd, UI_DEV_SETUP, &setup);
    ioctl(output_fd, UI_ABS_SETUP, &x);
    ioctl(output_fd, UI_ABS_SETUP, &y);
    ioctl(output_fd, UI_ABS_SETUP, &mt_x);
    ioctl(output_fd, UI_ABS_SETUP, &mt_y);
    ioctl(output_fd, UI_ABS_SETUP, &slot);
    ioctl(output_fd, UI_ABS_SETUP, &tracking_id);
    if (ioctl(output_fd, UI_DEV_CREATE) < 0) {
        fprintf(stderr, "UI_DEV_CREATE: %s\n", strerror(errno));
        exit(1);
    }
    usleep(250000);
}

int main(int argc, char **argv) {
    setup_device();

    if (argc >= 4 && strcmp(argv[1], "tap") == 0) {
        int x = atoi(argv[2]);
        int y = atoi(argv[3]);
        int hold_ms = argc >= 5 ? atoi(argv[4]) : 150;

        touch_down(x, y);
        usleep((useconds_t)hold_ms * 1000);
        touch_up();
    } else if (argc >= 4 && strcmp(argv[1], "doubletap") == 0) {
        int x = atoi(argv[2]);
        int y = atoi(argv[3]);
        int hold_ms = argc >= 5 ? atoi(argv[4]) : 60;
        int gap_ms = argc >= 6 ? atoi(argv[5]) : 120;

        touch_down(x, y);
        usleep((useconds_t)hold_ms * 1000);
        touch_up();
        usleep((useconds_t)gap_ms * 1000);
        touch_down(x, y);
        usleep((useconds_t)hold_ms * 1000);
        touch_up();
    } else if (argc >= 6 && strcmp(argv[1], "drag") == 0) {
        int x1 = atoi(argv[2]);
        int y1 = atoi(argv[3]);
        int x2 = atoi(argv[4]);
        int y2 = atoi(argv[5]);
        int duration_ms = argc >= 7 ? atoi(argv[6]) : 900;
        int steps = argc >= 8 ? atoi(argv[7]) : 24;
        useconds_t delay;

        if (steps < 1) {
            steps = 1;
        }
        delay = (useconds_t)duration_ms * 1000 / steps;
        touch_down(x1, y1);
        for (int step = 1; step <= steps; step++) {
            usleep(delay);
            touch_move(x1 + (x2 - x1) * step / steps,
                       y1 + (y2 - y1) * step / steps);
        }
        usleep(80000);
        touch_up();
    } else {
        fprintf(stderr,
                "usage: %s tap X Y [HOLD_MS]\n"
                "       %s doubletap X Y [HOLD_MS] [GAP_MS]\n"
                "       %s drag X1 Y1 X2 Y2 [DURATION_MS] [STEPS]\n",
                argv[0], argv[0], argv[0]);
        ioctl(output_fd, UI_DEV_DESTROY);
        return 2;
    }

    usleep(100000);
    ioctl(output_fd, UI_DEV_DESTROY);
    close(output_fd);
    return 0;
}
