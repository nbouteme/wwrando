
; 8005D618 is where the game calls the new game save init function.
; We replace this call with a call to our custom save init function.
.open "sys/main.dol"
.org 0x8005D618
  bl init_save_with_tweaks




; nop out a couple lines so the long intro movie is skipped.
.open "sys/main.dol"
.org 0x80232C78
  nop
.org 0x80232C88
  nop




; Modify King of Red Lions's code so he doesn't stop you when you veer off the path he wants you to go on.
.open "files/rels/d_a_ship.rel"
; We need to change some of the conditions in his checkOutRange function so he still prevents you from leaving the bounds of the map, but doesn't railroad you based on your story progress.
; First is the check for before you've reached Dragon Roost Island. Make this branch unconditional so it considers you to have seen Dragon Roost's intro whether you have or not.
.org 0x29EC
  b 0x2A50
; Second is the check for whether you've gotten Farore's Pearl. Make this branch unconditional too.
.org 0x2A08
  b 0x2A50
; Third is the check for whether you have the Master Sword. Again make the branch unconditional.
.org 0x2A24
  b 0x2A34
; Skip the check for if you've seen the Dragon Roost Island intro which prevents you from getting in the King of Red Lions.
; Make this branch unconditional as well.
.org 0xB2D8
  b 0xB2F0




; Normally the Great Fairies will give you the next tier max-up upgrade, depending on what you currently have.
; So if you already got the 1000 Rupee Wallet from one Great Fairy, the second one will give you the 5000 Rupee Wallet, regardless of the order you reach them in.
; This patch changes it so they always give a constant item even if you already have it, so that the item can be randomized safely.
.open "files/rels/d_a_bigelf.rel" ; Great Fairy
.org 0x217C
  ; Check this Great Fairy's index to determine what item to give.
  cmpwi r0, 1
  blt 0x21B8 ; 0, Northern Fairy Island Great Fairy. Give 1000 Rupee Wallet.
  beq 0x21C4 ; 1, Outset Island Great Fairy. Give 5000 Rupee Wallet.
  cmpwi r0, 3
  blt 0x21E4 ; 2, Eastern Fairy Island Great Fairy. Give 60 Bomb Bomb Bag.
  beq 0x21F0 ; 3, Southern Fairy Island Great Fairy. Give 99 Bomb Bomb Bag.
  cmpwi r0, 5
  blt 0x2210 ; 4, Western Fairy Island Great Fairy. Give 60 Arrow Quiver.
  beq 0x221C ; 5, Thorned Fairy Island Great Fairy. Give 99 Arrow Quiver.
  b 0x2228 ; Failsafe code in case the index was invalid (give a red rupee instead)




; Fishmen usually won't appear until Gohma is dead. This removes that check from their code so they appear from the start.
.open "files/rels/d_a_npc_so.rel" ; Fishman
.org 0x3FD8
  ; Change the conditional branch to an unconditional branch.
  b 0x3FE4




; The event where the player gets the Wind's Requiem actually gives that song to the player twice.
; The first one is hardcoded into Zephos's AI and only gives the song.
; The second is part of the event, and also handles the text, model, animation, etc, of getting the song.
; Getting the same item twice is a problem for some items, such as rupees. So we remove the first one.
.open "files/rels/d_a_npc_hr.rel" ; Zephos
.org 0x1164
  ; Branch to skip over the line of code where Zephos gives the Wind's Requiem.
  b 0x116C




; The 6 Heart Containers that appear after you kill a boss are all created by the function createItemForBoss.
; createItemForBoss hardcodes the item ID 8, and doesn't care which boss was just killed. This makes it hard to randomize boss drops without changing all 6 in sync.
; So we make some changes to createItemForBoss and the places that call it so that each boss can give a different item.
.open "sys/main.dol"
; First we modify the createItemForBoss function itself to not hardcode the item ID as 8 (Heart Container).
; We nop out the two instructions that load 8 into r4. This way it simply passes whatever it got as argument r4 into the next function call to createItem.
.org 0x80026A90
  nop
.org 0x80026AB0
  nop
; Second we modify the code for the "disappear" cloud of smoke when the boss dies.
; This cloud of smoke is what spawns the item when Gohma, Kalle Demos, Helmaroc King, and Jalhalla die.
; So we need a way to pass the item ID from the boss's code to the disappear cloud's parameters and store them there.
; We do this by hijacking argument r7 when the boss calls createDisappear.
; Normally argument r7 is a byte, and gets stored to the disappear's params with mask 00FF0000.
; We change it to be a halfword and stored with the mask FFFF0000.
; The lower byte is unchanged from vanilla, it's still whatever argument r7 used to be for.
; But the upper byte, which used to be unused, now has the item ID in it.
.org 0x80027AC4
  rlwimi r4, r7, 16, 0, 15
; Then we need to read the item ID parameter when the cloud is about to call createItemForBoss.
.org 0x800E7A1C
  lbz r4, 0x00B0(r7)
; Third we change how the boss item ACTR calls createItemForBoss.
; (This is the ACTR that appears if the player skips getting the boss item after killing the boss, and instead comes back and does the whole dungeon again.)
; Normally it sets argument r4 to 1, but createItemForBoss doesn't even use argument r4.
; So we change it to load one of its params (mask: 0000FF00) and use that as argument r4.
; This param was unused and just 00 in the original game, but the randomizer will set it to the item ID it randomizes to that location.
; Then we will be calling createItemForBoss with the item ID to spawn in argument r4. Which due to the above change, will be used correctly now.
.open "files/rels/d_a_boss_item.rel"
.org 0x1C4
  lbz r4, 0x00B2(r30)
; The final change necessary is for all 6 bosses' code to be modified so that they pass the item ID to spawn to a function call.
; For Gohdan and Molgera, the call is to createItemForBoss directly, so argument r4 needs to be the item ID.
; For Gohma, Kalle Demos, Helmaroc King, and Jalhalla, they instead call createDisappear, so we need to upper byte of argument r7 to have the item ID.
; But the randomizer itself handles all 6 of these changes when randomizing, since these locations are all listed in the "Paths" of each item location. So no need to do anything here.




; This makes the warps out of boss rooms always skip the cutscene usually shown the first time you beat the boss and warp out.
.open "files/rels/d_a_warpf.rel" ; Warp out of boss object
.org 0xC3C
  ; Function C3C of d_a_warpf.rel is checking if the post-boss cutscene for this dungeon has been viewed yet or not.
  ; Change it to simply always return true, so that it acts like it has been viewed from the start.
  li r3, 1
  blr




; The Great Fairy inside the Big Octo is hardcoded to double your max magic meter (and fill up your current magic meter too).
; Since we randomize what item she gives you, we need to remove this code so that she doesn't always give you the increased magic meter.
.open "files/rels/d_a_bigelf.rel" ; Great Fairy
.org 0x7C4
  nop ; For max MP
.org 0x7D0
  nop ; For current MP
; Also, the magic meter upgrade item itself only increases your max MP.
; In the vanilla game, the Great Fairy would also refill your MP for you.
; Therefore we modify the code of the magic meter upgrade to also refill your MP.
.open "sys/main.dol"
.org 0x800C4D14
  ; Instead of adding 32 to the player's previous max MP, simply set both the current and max MP to 32.
  li r0, 32
  sth r0, 0x5B78 (r4)




; When salvage points decide if they should show their ray of light, they originally only checked if you
; have the appropriate Triforce Chart deciphered if the item there is actually a Triforce Shard.
; We don't want the ray of light to show until the chart is deciphered, so we change the salvage point code
; to check the chart index instead of the item ID when determining if it's a Triforce or not.
.open "files/rels/d_a_salvage.rel" ; Salvage point object
.org 0x10C0
  ; We replace the call to getItemNo, so it instead just adds 0x61 to the chart index.
  ; 0x61 to 0x68 are the Triforce Shard IDs, and 0 to 8 are the Triforce Chart indexes,
  ; so by adding 0x61 we simulate whether the item would be a Triforce Shard or not based on the chart index.
  addi r3, r19, 0x61
  ; Then we branch to skip the line of code that originally called getItemNo.
  ; We can't easily nop the line out, since the REL's relocation would overwrite our nop.
  b 0x10CC




; The first instance of Medli, who gives the letter for Komali, can disappear under certain circumstances.
; For example, owning the half-power Master Sword makes her disappear. Deliving the letter to Komali also makes her disappear.
; So in order to avoid the item she gives being missable, we just remove it entirely.
; To do this we modify the chkLetterPassed function to always return true, so she thinks you've delivered the letter.
.open "sys/main.dol"
.org 0x8021BF80
  li r3, 1




; Normally Medli would disappear once you own the Master Sword (Half Power).
; This could make the Earth Temple uncompletable if you get the Master Sword (Half Power) before doing it.
; So we slightly modify Medli's code to not care about your sword.
.open "files/rels/d_a_npc_md.rel" ; Medli
.org 0xA24
  ; Make branch that depends on your sword unconditional instead.
  b 0xA60




; Remove the cutscene where the Tower of the Gods rises out of the sea.
; To do this we modify the goddess statue's code to skip starting the raising cutscene.
; Instead we branch to code that ends the current pearl-placing event after the tower raised event bit is set.
.open "files/rels/d_a_obj_doguu.rel" ; Goddess statues
.org 0x267C
  b 0x26A0




; Normally whether you can use Hurricane Spin or not is determined by if the event bit for the event where Orca teaches it to you is set or not.
; But we want to separate the ability from the event so they can be randomized.
; To do this we change the check for the event bit to instead be a check for bit 80 of byte 803C4CBF.
; The lower bits of byte 803C4CBF are used to keep track of whether you have the Pirate's Charm or not, but bit 80 is unused, so we can safely use it for Hurricane Spin.
.open "sys/main.dol"
.org 0x80158BFC
  lis r3,0x803C4CBC@ha
  addi r3,r3,0x803C4CBC@l
  li r4,3
  li r5,7
  bl isCollect__20dSv_player_collect_cFiUc
; Then change the Hurricane Spin's item get func to our custom function which sets this previously unused bit.
.org 0x80388B70 ; 0x803888C8 + 0xAA*4
  .int hurricane_spin_item_func




; Normally Beedle checks if you've bought the Bait Bag by actually checking if you own the Bait Bag item.
; That method is problematic for many items that can get randomized into that shop slot, including progressive items.
; So we change the functions he calls to set the slot as sold out and check if it's sold out to custom functions.
; These custom functions use bit 40 of byte 803C4CBF, which was originally unused, to keep track of this.
.open "files/rels/d_a_npc_bs1.rel" ; Beedle
.org 0x7834
  ; Change the relocation for line 1CE8, which originally called SoldOutItem.
  .int set_shop_item_in_bait_bag_slot_sold_out
.org 0x7BD4
  ; Change the relocation for line 2DC4, which originally called checkGetItem.
  .int check_shop_item_in_bait_bag_slot_sold_out




; Originally the withered trees and the Koroks next to them only appear after you get Farore's Pearl.
; This gets rid of all those checks so they appear from the start of the game.
.open "files/rels/d_a_obj_ftree.rel" ; Withered Trees
.org 0xA4C
  nop
.open "files/rels/d_a_npc_bj1.rel" ; Koroks
.org 0x784
  li r0, 0x1F
  li r31, 0
.org 0x830
  li r0, 0x1F
  li r30, 0
.org 0x984
  li r0, 0x1F
  li r31, 0
.org 0xA30
  li r0, 0
.org 0x2200
  nop




; The item buried under black soil and the item given by the withered trees are spawned by a call to fastCreateItem.
; This is bad since fastCreateItem doesn't load the field item model in. If the model isn't already loaded the game will crash.
; So we add a new custom function to create an item and load the model, and replace the relevant calls so they call the new function.
; Buried item
.open "sys/main.dol"
.org 0x80056C0C
  bl custom_createItem
; Withered trees
.open "files/rels/d_a_obj_ftree.rel" ; Withered Trees
; This is a rel, so overwrite the relocation addresses instead of the actual code.
.org 0x60E8
  .int custom_createItem
.org 0x6190
  .int custom_createItem
; Also change the code that reads the entity ID from entity+4 to instead read from entity+3C.
; I'm not sure why, but the location of the ID in the entity returned by fastCreateItem and this custom function are different.
.org 0x26C
  lwz r0,0x3C(r31)
.org 0x428
  lwz r0,0x3C(r3)




; In order to get rid of the cutscene where the player warps down to Hyrule 3, we set the HYRULE_3_WARP_CUTSCENE event bit on starting a new game.
; But then that results in the warp appearing even before the player should unlock it.
; So we replace a couple places that check that event bit to instead call a custom function that returns whether the warp should be unlocked or not.
.open "files/rels/d_a_warpdm20.rel" ; Hyrule warp object
; This is a rel, so overwrite the relocation addresses instead of the actual code.
.org 0x2530
  .int check_hyrule_warp_unlocked
.org 0x2650
  .int check_hyrule_warp_unlocked




; The warp object down to Hyrule sets the event bit to change FF2 into FF3 once the event bit for seeing Tetra transform into Zelda is set.
; We want FF2 to stay permanently, so we skip over the line that sets this bit.
.open "files/rels/d_a_warpdm20.rel" ; Hyrule warp object
.org 0x68C
  b 0x694