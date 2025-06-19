# OctoChris' Matchmaking Script
A script by OctoChris to handle ranked PVP matchmaking on Open Net Battle servers.

![preview](https://github.com/user-attachments/assets/bf010971-1783-451a-befd-b6decb6cfeeb)

### What does it do?

This script allows users to enter free (unranked) or ranked matchmaking queues, as well as, view a leaderboard based on performance by their fellow players. The `Matchmaking Settings` menu is accessed via the Left Shoulder button. The `Matchmaking Request` is accessed by interacting with another plaver.

### How do I install it on my server?

1. Add the `demo-server/scripts/octo-ranking` folder from this repository to your `/scripts` folder.
2. For any net area you want to enable match making add a string based custom property named `OctoPVP` and make the value `true`. 

### What improvements were made from the original script by OctoChris?

1. The script is now stand alone and no longer requires ezlibs.
2. The matchmaking settings and matchmaking request menu have been seperated.
3. Activating the menu requires specific button presses (before all buttons would activate the menu).
4. Matchmaking in an area is enabled via a Custom Property (before you had to modify the script). 

### How is rank determined?

Numerical rating (and thus Letter Rank) is calculated using this formula (assuming abandoned matches/disconnections don't count):<br> 
((((Ranked Wins - Ranked Losses) ÷ Ranked Games Overall) × 0.5) + 0.5) × 50000 = Rating

50000 is the maximum ELO rating a player can achieve.

This is a conversion table between the numerical rating and the letter rank: 
![ELORatingGraphic](https://github.com/user-attachments/assets/5bd2cfe0-23d1-46d5-8c5f-02e3a8e87409)

### Credit

Original Script - OctoChris
Improvements - Indiana
