#include <stdio.h>
#include <string.h>
#ifdef HAVE_SDL2
#include <SDL2/SDL.h>
#else
#include "SDL.h"
#endif
#include "vga_13.h"
#include "font8x8.h"
#include "menu.h"

struct MenuItem {
  const char *label;
  const char *desc;
};

struct Scenario {
  const char *label;
  const char *flt;
  const char *wld;
  const char *grnd;
  int rnd;
  int no_crash;
};

static const Scenario missions[] = {
  {"Just Fly (no crash)",          "fly.flt",      "a.wld",   NULL,    0, 1},
  {"Takeoff from Runway",          "takeoff.flt",  "a.wld",   NULL,    0, 0},
  {"Target Practice 1",            "shoot1.flt",   "a.wld",   NULL,    0, 0},
  {"Target Practice 2",            "shoot2.flt",   "a.wld",   NULL,    0, 0},
  {"Target Practice 3",            "shoot3.flt",   "a.wld",   NULL,    0, 0},
  {"Dogfight - 1v1 MiG-15",        "dogfight.flt", "a.wld",   NULL,    1, 0},
  {"Furball - Mass Air Combat",    "furball.flt",  "a.wld",   "a.gru", 1, 0},
  {"Melee - Five on Five",         "melee.flt",    "a.wld",   NULL,    0, 0},
  {"MiG Jump - Ride with Cdr Jing","migjump.flt",  "a.wld",   NULL,    0, 0},
  {"Yak Attack - Mustang vs Yak",  "yakattak.flt", "a.wld",   NULL,    1, 0},
  {"Thunder - F-84 vs MiG-15",     "thunder.flt",  "a.wld",   NULL,    0, 0},
  {"Pistons - Prop Fighters",      "pistons.flt",  "a.wld",   NULL,    0, 0},
  {"Ground Attack 1 - F-84",       "gru.flt",      "gru.wld", "b.gru", 0, 0},
  {"Ground Attack 2 - F-86",       "gru2.flt",     "gru.wld", "b.gru", 0, 0},
  {"Ground Attack 3 - F-86",       "gru3.flt",     "gru.wld", "b.gru", 0, 0},
};
static const int NUM_MISSIONS = sizeof(missions) / sizeof(missions[0]);

static const Scenario demos[] = {
  {"Furball - Mass Air Combat",    "furball.flt",  "a.wld",   NULL,    0, 0},
  {"Melee - Five on Five",         "melee.flt",    "a.wld",   NULL,    0, 0},
  {"MiG Jump - Ride with Cdr Jing","migjump.flt",  "a.wld",   NULL,    0, 0},
  {"Yak Attack - Mustang vs Yak",  "yakattak.flt", "a.wld",   NULL,    0, 0},
  {"Thunder - F-84 vs MiG-15",     "thunder.flt",  "a.wld",   NULL,    0, 0},
  {"Pistons - Prop Fighters",      "pistons.flt",  "a.wld",   NULL,    0, 0},
};
static const int NUM_DEMOS = sizeof(demos) / sizeof(demos[0]);

static int sound_enabled = 1;

static void drawText(int x, int y, int color, const char *text)
{
  if (g_font)
    g_font->font_sprintf(x, y, color, NORMAL, "%s", text);
}

static void clearScreen()
{
  unsigned char *buf = lock_xbuff();
  memset(buf, 0, SCREEN_WIDTH * SCREEN_HEIGHT);
}

static void drawTitle()
{
  int cx = SCREEN_WIDTH / 2;
  drawText(cx - 120, 30, 15, "SABRE FIGHTER PLANE SIMULATOR");
  drawText(cx - 70, 45, 7, "Version " VERSION);
  drawText(cx - 100, 65, 8, "Korean War Air Combat 1950-1953");
}

static void drawBox(int x, int y, int w, int h, int color)
{
  h_line(x, y, w, color);
  h_line(x, y + h, w, color);
  v_line(x, y, h, color);
  v_line(x + w, y, h, color);
}

static int waitKey()
{
  SDL_Event e;
  while (1) {
    while (SDL_PollEvent(&e)) {
      if (e.type == SDL_KEYDOWN)
        return e.key.keysym.sym;
      if (e.type == SDL_QUIT)
        return SDLK_ESCAPE;
    }
    SDL_Delay(16);
  }
}

static int drawMenu(const char *title, const MenuItem *items, int count, int selected)
{
  clearScreen();
  drawTitle();

  int startY = 90;
  int cx = SCREEN_WIDTH / 2;

  drawText(cx - static_cast<int>(strlen(title)) * 3, startY, 14, title);
  drawBox(cx - 160, startY + 15, 320, count * 16 + 10, 8);

  for (int i = 0; i < count; i++) {
    int y = startY + 22 + i * 16;
    int color = (i == selected) ? 14 : 7;
    if (i == selected) {
      for (int row = y - 1; row < y + 9; row++)
        h_line(cx - 155, row, 310, 1);
      color = 15;
    }
    char line[80];
    if (items[i].desc && items[i].desc[0])
      snprintf(line, sizeof(line), "  %s - %s", items[i].label, items[i].desc);
    else
      snprintf(line, sizeof(line), "  %s", items[i].label);
    drawText(cx - 150, y, color, line);
  }

  int bottomY = startY + 30 + count * 16;
  drawText(cx - 100, bottomY + 5, 8, "UP/DOWN to select, ENTER to choose");
  drawText(cx - 60, bottomY + 17, 8, "ESC to go back");

  blit_buff();
  return 0;
}

static int runMenu(const char *title, const MenuItem *items, int count)
{
  int sel = 0;
  while (1) {
    drawMenu(title, items, count, sel);
    int key = waitKey();
    switch (key) {
    case SDLK_UP:
      sel = (sel - 1 + count) % count;
      break;
    case SDLK_DOWN:
      sel = (sel + 1) % count;
      break;
    case SDLK_RETURN:
    case SDLK_KP_ENTER:
      return sel;
    case SDLK_ESCAPE:
      return -1;
    }
  }
}

static int selectScenario(const char *title, const Scenario *scenarios, int count, MenuResult &result)
{
  MenuItem items[16];
  for (int i = 0; i < count && i < 16; i++) {
    items[i].label = scenarios[i].label;
    items[i].desc = "";
  }
  int sel = runMenu(title, items, count);
  if (sel < 0) return 0;

  result.flight_file = scenarios[sel].flt;
  result.world_file = scenarios[sel].wld;
  result.ground_file = scenarios[sel].grnd;
  result.do_random = scenarios[sel].rnd;
  result.no_crash = scenarios[sel].no_crash;
  return 1;
}

static void settingsMenu(MenuResult &result)
{
  while (1) {
    char snd_label[32], snd_desc[32];
    snprintf(snd_label, sizeof(snd_label), "Sound");
    snprintf(snd_desc, sizeof(snd_desc), "[%s]", sound_enabled ? "ON" : "OFF");

    MenuItem items[] = {
      {snd_label, snd_desc},
      {"Back", ""},
    };
    int sel = runMenu("SETTINGS", items, 2);
    if (sel == 0)
      sound_enabled = !sound_enabled;
    else
      break;
  }
  result.want_sound = sound_enabled;
}

static void initMenuPalette()
{
  set_rgb_value(0, 0, 0, 0);
  for (int i = 1; i < 8; i++) {
    char v = static_cast<char>(i * 8);
    set_rgb_value(i, v, v, v);
  }
  for (int i = 8; i < 16; i++) {
    char v = static_cast<char>(i * 4);
    set_rgb_value(i, v, v, v);
  }
  set_rgb_value(7, 42, 42, 42);
  set_rgb_value(8, 20, 20, 25);
  set_rgb_value(14, 55, 55, 15);
  set_rgb_value(15, 63, 63, 63);
  set_rgb_value(1, 8, 12, 20);
}

static MenuResult g_pendingResult;
static bool g_hasPending = false;

void setupMenu()
{
}

int menuPending()
{
  return g_hasPending ? 1 : 0;
}

MenuResult getMenuResult()
{
  g_hasPending = false;
  return g_pendingResult;
}

int menuKeyPending()
{
  return 0;
}

int getMenuKey()
{
  return 0;
}

static MenuResult showMenu()
{
  MenuResult result;
  memset(&result, 0, sizeof(result));
  result.flight_file = "fly.flt";
  result.world_file = "a.wld";
  result.ground_file = NULL;
  result.demo = 0;
  result.do_random = 0;
  result.no_crash = 0;
  result.want_sound = sound_enabled;
  result.quit = 0;

  initMenuPalette();

  while (1) {
    MenuItem mainItems[] = {
      {"Fly Mission",   "Fly a combat scenario"},
      {"Watch Demo",    "Watch AI pilots in action"},
      {"Settings",      "Configure game options"},
      {"Quit",          "Exit to desktop"},
    };
    int sel = runMenu("MAIN MENU", mainItems, 4);

    if (sel == 0) {
      result.demo = 0;
      if (selectScenario("SELECT MISSION", missions, NUM_MISSIONS, result))
        return result;
    } else if (sel == 1) {
      result.demo = 1;
      if (selectScenario("SELECT DEMO", demos, NUM_DEMOS, result))
        return result;
    } else if (sel == 2) {
      settingsMenu(result);
    } else {
      result.quit = 1;
      return result;
    }
  }
}
