BESTAGON
========

A micro arena survivor. WASD to move; your weapons fire themselves.
Five minutes to win. Something worse waits at ten.

(No date here on purpose. The zip filename carries the build date, and a
date written into prose is one that goes stale without anyone noticing.)


READ THIS FIRST IF YOU HAVE THE WEB VERSION
-------------------------------------------
DO NOT double-click index.html.

You will get the Godot logo and the message "Failed to fetch". Nothing is
broken. A browser refuses to load the game's data files when the page is
opened straight off the disk, because a file:// page has no origin the
browser trusts. The page has to come from a server.

    Double-click START-HERE.bat instead. It starts one and opens the game.
    Leave that black window open while you play.

(START-HERE.bat needs Python installed. If you do not have it, just grab
the Windows version — it is a single .exe and needs none of this. Or play
it in the browser on itch.io, where the server is already there.)


HOW TO RUN
----------
Windows : run BESTAGON.exe. Windows SmartScreen will warn about an
          unsigned .exe, which is expected for an indie build with no
          code-signing certificate: "More info" -> "Run anyway".

Browser : double-click START-HERE.bat (see above), or host the folder
          anywhere that serves over http/https — itch.io as an HTML game
          with a 1280x720 embed works as-is.


CONTROLS
--------
  WASD / arrows   move
  SPACE           dash (unlocked by beating the 5:00 boss)
  ESC / P         pause — also where the build sheet, the volume sliders
                  and the music track selector live
  M               mute
  R  (twice)      restart — first press asks, second confirms


NOTES
-----
Progress saves locally — per browser profile for the web version, so
clearing site data resets it. A second run starts with a little more than
the first.

The music is four tracks that each play as four separate layers, fading in
and out with how much trouble you are in. Nothing about it is randomised;
it is written that way. The pause menu lets you pin one track if you would
rather it stopped rotating.

Found something that reads as BROKEN rather than hard? That distinction is
the single most useful thing you can report.


IF IT CRASHES OR FREEZES (Windows)
----------------------------------
Double-click COLLECT-LOGS.bat and send the zip it drops on your Desktop.

That is it. The game writes a log to a folder nobody should be expected to
find, and the zip also picks up which graphics card and driver you are on,
which is usually the half of the report that actually answers the question.

If the game is still frozen on screen, close it FIRST, then run the file.
Nothing is lost by closing it - the log is written as it goes.
