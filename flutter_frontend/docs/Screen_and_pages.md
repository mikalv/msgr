# Screen and pages

# What's the difference?

In this project a Screen is something isolated to itself, and you'll find most of them when the user isn't signed in.
Like Login, Welcome screen etc.

MainScreen however has this navigation bar, and it's here every page lives under. So a page is basically a sub-view of the MainScreen.

Another way of explaining it; a Screen takes the whole screen/window, while a page is embedded into a view with MsgrBottomNavBar at the bottom.
