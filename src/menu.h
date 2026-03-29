#ifndef MENU_H
#define MENU_H

struct MenuResult {
  const char *flight_file;
  const char *world_file;
  const char *ground_file;
  int demo;
  int do_random;
  int no_crash;
  int want_sound;
  int quit;
};

void setupMenu();
int menuPending();
MenuResult getMenuResult();
int menuKeyPending();
int getMenuKey();

#endif
