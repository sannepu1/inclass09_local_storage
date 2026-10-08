# In-Class 09 Local Storage Part II - Saurav Annepu

CSC 4360 Mobile Application Development
Pathway: Undergraduate

## Setup

- Flutter 3.47.2 and Dart 3.13.2 and i ran it on the Medium Phone Android emulator
- Run `flutter pub get` and then `flutter run -d emulator-5554`
- For the release build run `flutter build apk --release`
- I did all the testing by hand (T1 to T6 below) and `flutter analyze` said no issues

## Database and migration

- So it's still the same MyDatabase.db file and the version went from 1 to 2
- onUpgrade only runs if the old version is under 2 and it basically just adds the folders and cards tables and the index so my Part I table (my_table) never gets touched
- cards has a folder_id that points to folders and it uses ON DELETE CASCADE so if you delete a folder its cards go with it. Foreign keys get turned on in onConfigure or else the cascade kind of does nothing.
- Part I had 3 rows before the upgrade (River 2 and Acorn 3 and Oak 4) and it still had the same 3 after

## Image choice

So i store image_ref as text that can be null and not the actual image. If it's empty or the file is missing the card just shows its suit symbol and it doesnt crash.

## Tests

| Test | Expected | What happened | Pass/Fail |
|---|---|---|---|
| T1 Upgrade | Part I rows are still there | Same 3 rows (River 2 and Acorn 3 and Oak 4) and Records: 3 after the upgrade | Pass |
| T2 Create | 3 cards with different IDs in the right folders | Spades Drawer (ID 1) had cards 1 and 2 and Hearts Drawer (ID 2) had card 3 and the counts said 2 and 1 | Pass |
| T3 Edit | Only one row changes and cancel saves nothing | Card 1 notes saved and said "Rows affected: 1" and cancelling card 2 didnt change anything | Pass |
| T4 Restart | Same data after a force stop | Same folders and IDs and counts and nothing doubled | Pass |
| T5 Delete | Cancel does nothing and delete takes out the folder and its cards | Cancel kept it and delete said "Rows affected: 1" and folders went to 1. The new Hearts Drawer got ID 3 with 0 cards so card 3 was really gone. | Pass |
| T6 Bad input and image | Placeholder shows and bad input doesnt save | The missing image showed the ♠ placeholder and blank title and no suit both showed errors and nothing saved | Pass |

For T4 i pressed q and then ran `adb shell am force-stop com.example.local_storage_lab` and then opened it from the app icon.

For the release APK i installed it on the emulator with `adb install -r` and it said Success and it opened fine and the Part I guests were still there.

The screenshots and analyzer output are in the evidence folder (T1_before.png and T2_cards.png and T4_after.png and analysis_output.txt plus some extra ones).

## Rubric map

- Schema and keeping old data is in lib/database_helper.dart and T1 and T5
- Models and repository and CRUD is in lib/models and lib/data/catalog_repository.dart and T2 and T3
- Image and usability is in lib/widgets/card_image.dart and T6
- Testing is the table above and the evidence folder

## Limitations

- I only tested on Android since the iPhone simulator wouldnt build
- I didnt do a separate fresh install test
- There's no image picker so you have to type the image ref in by hand

## Credits and AI use

The starter was the Part I database_helper.dart. I used ChatGPT to help debug and help write some of the code. I also used Claude to help with the Part II code and this README. I ran the app and did all the tests myself and the results are from my own emulator.
