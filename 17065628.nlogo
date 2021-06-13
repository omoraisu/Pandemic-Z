;;Zombie Apocalypse

breed [humans human]                                                                 ; create a population of humans
breed [zombies zombie]                                                               ; create a population of zombies
breed [food foods]                                                                   ; creating a population of food for the humans to feed from
breed [gun guns]                                                                     ; creating a population of guns for the humans to have it
breed [rambo rambos]                                                                 ; creating a population of armed humans to kill zombies

globals [radius timer_reset                                                          ; this creates 2 global variables called radius and timer_reset
  daytime starting_color current_color                                               ; this creates 2 global variables relating to creating day and night within our model
  color_adjust color_range                                                           ; this creates 2 global variables relating to creating day and night within our model
  death_by_starvation death_by_zombie                                                ; this creates 2 global variables with the cause of death used for plotting
]

patches-own [solid]                                                                  ; this creates a variable for the patches to establish if it should be percived as solid

turtles-own [
  health age                                                                         ; this creates 2 variables called health and age for humans
  food_around_me closest_food                                                        ; this creates 2 variables to save the locations of food
  gun_around_me closest_gun                                                          ; this creates 2 variables to save the locations of gun
  ammo amount                                                                        ; this creates 2 variables called ammo and amount
  per_vision_radius per_vision_angle                                                 ; this creates variables for personalised vision cones
  vision_cone_random                                                                 ; this creates a variable to store a stable vision cone random value
]

to setup                                                                             ; this creates a function called setup
  clear-all                                                                          ; this clears the world of any previous activities
  reset-ticks                                                                        ; this resets the ticks counter
  set radius 3                                                                       ; this sets the global variable radius to 3
  set timer_reset 500                                                                ; this sets the global variable reset_timer to 500
  set daytime true                                                                   ; this sets the global variable daytime to true
  set starting_color 85                                                              ; this sets the global variable starting_color to 85 which is cyan
  set current_color starting_color                                                   ; this sets the global variable current_color to starting_color
  set color_range 10                                                                 ; this sets the global variable color_range to 10
  set color_adjust ( color_range / ( timer_reset + 10 ))                             ; this sets the global variable color_adjust to a range based on the variables above
  make-humans                                                                        ; this calls the make-humans function
  make-zombies                                                                       ; this calls the make-zombies function
  make-rambos                                                                        ; this calls the make-rambos function
  grow-food                                                                          ; this calls the grow-food function
  spawn-guns                                                                         ; this calls the spawn-guns function
  draw-building                                                                      ; this calls the draw-building function
end

to go                                                                                ; this creates a function called go
  reset-patch-colour                                                                 ; this calls the reset-patch-colour function
  make-humans-move                                                                   ; this calls the make-humans-move function
  make-zombies-move                                                                  ; this calls the make-zombies-move function
  make-rambos-move                                                                   ; this calls the make-rambos-move function
  tick                                                                               ; this adds 1 to the tick counter
  spawn-more-resources                                                               ; this calls the spawn-more-resources function
  check-winner                                                                       ; this calls the check-winner function
end


;;;;;;;;;;;;
;; HUMANS ;;
;;;;;;;;;;;;

to make-humans
  set-default-shape humans "person"                                                  ; this sets the default shape of the humans to a person
  create-humans number_of_humans [                                                   ; this creates the number of humans that your global variable states
    set color yellow                                                                 ; this sets the color of the humans to yellow
    set heading 0                                                                    ; this sets the starting heading of the human to 0
    setxy random-xcor random-ycor                                                    ; this sets the starting position of the humans to a random location in the world
    set age random 81                                                                ; this sets the age of the human to a random allocation up to 81
    set size ((0.6 * (age * 0.01)) + 0.4) * 12                                       ; this sets the size depending on the age
    set health 50 + (0.5 * ((-0.04 * ((age - 50)*(age - 50)) + 100))) - random 10    ; this sets the health of the human to 50 + a random allocation depending on the age
  ]
end

to make-humans-move                                                                  ; this creates a function called make-humans-move
  ask humans [                                                                       ; this asks all of the humans in the population to do what is in the brackets
    ifelse health > 0 [                                                              ; if health greater than 0 then...
      human-show-visualisations                                                      ; call the human-show-visualisations function
      adjust_vision_cone                                                             ; this calls the adjust_vision_cone fuction to setup the vision cone
      set color yellow                                                               ; this sets the color of each human to yellow
      let have_seen_zombie human-function                                            ; this creates a local variable called have_seen_zombie the fills it with the return of the function human-function
      let can_smell_food food-function 30                                            ; this creates a local variable called can_smell_food then fills it with the return of the function food-function whilst passing 30
      let can_see_gun gun-function 30                                                ; this creates a local variable called can_see_gun then fills it with the return of the function gun-function whilst passing 30
      if have_seen_zombie = true [                                                   ; if local variable have_seen_zombie is true...
        rt 40 + random 180                                                           ; this turn right 40 + a random allocation up to 180
      ]

      if have_seen_zombie = true [                                                   ; if local variable have_seen_zombie is true...
        rt 40 + random 180                                                           ; this turn right 40 + a random allocation up to 180
      ]

      ifelse (can_smell_food = true) and (health < 80) [                             ; if local variable can_smell_food is true and health less than 80 then...
        set heading (towards closest_food)                                           ; set heading towards closest food source
      ][                                                                             ; otherwise...

      if (can_see_gun = true) and (ammo < 5) and (age > 15) [                                     ; if local variable can_see_gun is true and ammo less than 5 then...
          set heading (towards closest_gun)                                          ; set heading towards closest gun source
        ]
      ]

      fd humans_speed * (( ((-0.04 * ((age - 50)*( age - 50)) + 100))) * 0.01 )      ; this sets the speed at which the human move depending on the age
    ][
      set death_by_starvation death_by_starvation + 1                                ; this increments the cause of death by starvation by one in order for plotting
      die                                                                            ; this kills off the human if health equals 0
    ]
  ]
end

to human-show-visualisations                                                         ; this creates a function called human-show-visualisations
  if show_col_rad = true [                                                           ; this will switch on the visualisation of the collision radius if the switch is set to true
    ask patches in-radius radius [                                                   ; this sets up a radius around the butterfly to the value of the global variable rad which we are using to display the size of the radius by changing the patch color
      if solid = false [                                                             ; this checks the patch is not solid
        set pcolor orange                                                            ; this sets the patch color to orange
      ]
    ]
  ]

  if show_vis_cone = true [                                                          ; this will switch on the visualisation of the vision cone if the switch is set to true
    ask patches in-cone humans_vision_radius humans_vision_angle [                   ; this sets up a vision cone to display the size of the cone by changing the patch color
      if solid = false [                                                             ; this checks the patch is not solid
        set pcolor orange                                                            ; this sets the patch color to orange
      ]
    ]
  ]
end

to-report food-function [sensitivity]                                                ; this creates a reporting function called food-function and expects a value for sensitivity
  set food_around_me other ( food in-radius sensitivity )                            ; this sets the food_around_me variable to the ID's of the food within the sensitivity radius
  set closest_food min-one-of food_around_me [distance myself]                       ; this sets the closest_food variable to the ID of the closest food source
  let can_smell_food [false]                                                         ; this creates a local variable called can_smell_food and sets it to false
  let eating_food [false]                                                            ; this creates a local variable called eating_food and sets it to false

  if health < 80 [                                                                   ; if health is less than 80 then...
    ask food in-radius radius [                                                      ; this sets up a radius around the food to the value of the global variable rad which we are using for collision detection with human
      ifelse amount > 0 [                                                            ; if amount is greater than 0 then...
        set eating_food true                                                         ; set the local variable called eating_food to true indicating the human is eating
        set amount amount - 5                                                        ; reduces 5 from the amount variable in the food
        set color color - .25                                                        ; reduce the color intensity of the food by .25
      ][                                                                             ; otherwise...
        die                                                                          ; there is no food left so kill the food agent
      ]
    ]
  ]

  if eating_food = true [                                                            ; if eating_food is true then...
    set health health + 5                                                            ; add 5 to health of human
  ]

  if (closest_food != nobody) [                                                      ; if closest_food is not empty (the human can smell food in range) then...
    set can_smell_food true                                                          ; set can_smell_food to true
  ]
  report can_smell_food                                                              ; return value of can_smell_food to location where function was called
end

to-report gun-function [intuition]                                                   ; this creates a reporting function called gun-function and expects a value for intuition
  set gun_around_me other ( gun in-radius intuition )                                ; this sets the gun_around_me variable to the ID's of the gun within the intuition radius
  set closest_gun min-one-of gun_around_me [distance myself]                         ; this sets the closest_gun variable to the ID of the closest gun source
  let can_see_gun [false]                                                            ; this creates a local variable called can_see_gun and sets it to false
  let pickup_gun [false]                                                             ; this creates a local variable called pickup_gun and sets it to false

  if ammo < 5 and age > 15[                                                          ; if ammo is less than 5 and age is greater than 15 then...
    ask gun in-radius radius [                                                       ; this sets up a radius around the gun to the value of the global variable radius which we are using for collision detection with human
      ifelse amount > 0 [                                                            ; if amount is greater than 0 then...
        set pickup_gun true                                                          ; set the local variable called pickup_gun to true indicating the human is picking
        set amount amount - 10                                                       ; reduces 10 from the amount variable in the gun
        set color color - .5                                                         ; reduce the color intensity of the gun by .5
      ][                                                                             ; otherwise...
        die                                                                          ; there is no gun left so kill the gun agent
      ]
    ]
  ]

  if pickup_gun = true [                                                             ; if pickup_gun is true then...
    set breed rambo                                                                  ; set humans to a new breed called rambo
    set ammo ammo + 10                                                               ; increase 10 from the ammo variable
  ]

  if (closest_gun != nobody) [                                                       ; if closest_gun is not empty (the human can see gun in range) then...
    set can_see_gun true                                                             ; set can_see_gun to true
  ]
  report can_see_gun                                                                 ; return value of can_see_gun to location where function was called
end

to-report human-function                                                             ; this creates a reporting function called human-function
  let seen [false]                                                                   ; this creates a local variable called seen and sets it to false

  if (remainder ticks 10 = 0) [                                                      ; this checks if the remainder is 0 when the ticks is 10
    set health health - 1                                                            ; reduces 1 from the health variable
  ]

  ask zombies in-cone humans_vision_radius humans_vision_angle [                     ; this sets up a vision cone with the parameters from humans_vision_radius humans_vision_angle to detects zombie
    set color blue                                                                   ; this sets the color of the zombie detected within the vision cone of the human to blue
    set seen true                                                                    ; this sets the local variable called seen to true indicating that a zombie has been seen
  ]

  report seen                                                                        ; return true or false based in local variable seen
end


;;;;;;;;;;;;
;; RAMBOS ;;
;;;;;;;;;;;;

to make-rambos
  set-default-shape rambo "person soldier"                                           ; this sets the default shape of the humans to a person soldier
end

to make-rambos-move                                                                  ; this creates a function called make-rambos-move
  ask rambo [                                                                        ; this asks all of the rambos in the population to do what is in the brackets
    ifelse health > 0 [                                                              ; if health greater than 0 then...
      human-show-visualisations                                                      ; call the human-show-visualisations function
      adjust_vision_cone                                                             ; this calls the adjust_vision_cone fuction to setup the vision cone
      let have_seen_zombie human-function                                            ; this creates a local variable called have_seen_zombie the fills it with the return of the function human-function
      let can_smell_food food-function 30                                            ; this creates a local variable called can_smell_food then fills it with the return of the function food-function whilst passing 30
      let can_see_gun gun-function 30                                                ; this creates a local variable called can_see_gun then fills it with the return of the function gun-function whilst passing 30

      if have_seen_zombie = true [                                                   ; if have_seen_zombie is true then...
        kill-zombie                                                                  ; call the kill-zombie function
      ]

      ifelse (can_smell_food = true) and (health < 80) [                             ; if local variable can_smell_food is true and health less than 80 then...
        set heading (towards closest_food)                                           ; set heading towards closest food source
      ][                                                                             ; otherwise...

      if (can_see_gun = true) and (ammo < 5) and (age > 15) [                                     ; if local variable can_see_gun is true and ammo less than 5 then...
          set heading (towards closest_gun)                                          ; set heading towards closest gun source
        ]
      ]

      fd humans_speed * (0.01 * ((-0.04 * ((age - 50)*(age - 50)) + 100)))           ; this sets the speed at which the human move depending on the age
    ][
      set death_by_starvation death_by_starvation + 1                                ; this increments the cause of death by starvation by one in order for plotting
      die                                                                            ; this kills off the rambo if health equals 0
    ]
  ]
end

to kill-zombie                                                                       ; this creates a function called kill-zombie
  let shoot [false]                                                                  ; this creates a local variable called shoot and sets it to false
  let zombie_shoot 0                                                                 ; this creates a local variable calles zombie_shoot and sets it to 0

  ask zombies in-radius humans_vision_radius [                                       ; this sets up a radius around the zombie to the value of the variable humans_vision_radius
    set shoot true                                                                   ; this sets the local variable called shoot to true
    set zombie_shoot who                                                             ; this sets the local variable called zombie_shoot to the individual who
  ]

  if shoot = true [                                                                  ; if shoot is true then...
    ifelse ammo > 0 [                                                                ; if ammo greater than 0 then...
      ask zombie zombie_shoot [die]                                                  ; this ask the zombie in-radius to die
      set ammo ammo - 1                                                              ; reduces 1 from the ammo variable
    ][
      set color green                                                                ; set color of human to green
    ]
  ]
end

to adjust_vision_cone                                                                ; this creates a function called adjust_vision_cone
  if ((((humans_vision_radius + vision_cone_random)*(health * 0.01))) - ((starting_color - current_color) * 2) > 0) [ ; if the calculation if greater than 0 then...
    set per_vision_radius (((humans_vision_radius + vision_cone_random)*(health * 0.01))) - ((starting_color - current_color) * 2)  ; set the personal vision radius to factor in some randomness and health (less health = less vision)
  ]
  if ((humans_vision_angle + vision_cone_random)*(health * 0.01)) > 0 [              ; if the calculation if greater than 0 then...
    set per_vision_angle ((humans_vision_angle + vision_cone_random)*(health * 0.01)) ; set the personal vision angle to factor in some randomness and health (less health = less vision)
  ]
end


;;;;;;;;;;;;;
;; ZOMBIES ;;
;;;;;;;;;;;;;

to make-zombies
  set-default-shape zombies "person"                                                 ; this sets the default shape of the zombies to a person
  create-zombies number_of_zombies [                                                 ; this creates the number of zombies that your global variable states
    set size 8                                                                       ; this sets the size of the zombies to 8
    set color red                                                                    ; this sets the color of the zombies to red
    setxy random-xcor 30 + random 150                                                ; this sets the starting position of the zombies to x = 30 + 150 to a random location in the world
  ]
end

to make-zombies-move                                                                 ; this creates a function called make-zombies-move
  ask zombies [                                                                      ; this asks all of the zombies in the population to do what is in the brackets
    set color red                                                                    ; this sets the color of each zombie to red
    zombie-show-visualisations                                                       ; call the zombie-show-visualisations function
    convert-humans                                                                   ; this calls the convert-humans function
    convert-rambos                                                                   ; this calls the convert-rambos function
    detect-wall                                                                      ; this calls the detect-wall function
    fd zombies_speed                                                                 ; this sets the speed at which the zombie move
  ]
end

to zombie-show-visualisations                                                        ; this creates a function called zombie-show-visualisations
  if show_col_rad = true [                                                           ; this will switch on the visualisation of the collision radius if the switch is set to true
    ask patches in-radius radius [                                                   ; this sets up a radius around the butterfly to the value of the global variable rad which we are using to display the size of the radius by changing the patch color
      if solid = false [                                                             ; this checks the patch is not solid
        set pcolor blue                                                              ; this sets the patch color to orange
      ]
    ]
  ]

  if show_vis_cone = true [                                                          ; this will switch on the visualisation of the vision cone if the switch is set to true
    ask patches in-cone zombies_vision_radius zombies_vision_angle [                 ; this sets up a vision cone to display the size of the cone by changing the patch color
      if solid = false [                                                             ; this checks the patch is not solid
        set pcolor blue                                                              ; this sets the patch color to blue
      ]
    ]
  ]
end

to convert-humans                                                                    ; this creates a function called convert-humans
  let seen [false]                                                                   ; this creates a local variable called seen and sets it to false
  let bit [false]                                                                    ; this creates a local variable called bit and sets it to false
  let human_bit 0                                                                    ; this creates a local variable calles human_bit and sets it to 0

  ask humans in-cone zombies_vision_radius zombies_vision_angle [                    ; this sets up a vision cone with the parameters from zombies_vision_radius zombies_vision_angle to detects human
    set color green                                                                  ; this sets the color of the human detected within the vision code of the zombie to green
    set seen true                                                                    ; this sets the local variable called seen to true indicating that a human has been seen
  ]

  ask humans in-radius radius [                                                      ; this sets up a radius around the zombie to the value of the global variable radius which we are using for collision detection with human
    set bit true                                                                     ; this sets the local variable called bit to true indicating that a human has collided with the zombie
    set human_bit who                                                                ; this sets the local variable called human_bit to the individual who
  ]

  if seen = true [                                                                   ; if seen is true then...
    face min-one-of humans [distance myself]                                         ; checks if human is near
    set color white                                                                  ; set color of zombie to white
  ]

  if bit = true [                                                                    ; if bit is true then...
    ask human human_bit [                                                            ; this asks all of the humans in the population to do what is in the brackets
      set death_by_zombie death_by_zombie + 1                                        ; this increments the cause of death by zoombie by one in order for plotting
      set breed zombies                                                              ; this sets the breed of the dead human to a zombie
      set shape "person"                                                             ; this sets the shape of the dead human to a person
    ]
    set color green                                                                  ; set color of zombie to green
  ]
end

to convert-rambos                                                                    ; this creates a function called convert-rambos
  let seen [false]                                                                   ; this creates a local variable called seen and sets it to false
  let bit [false]                                                                    ; this creates a local variable called bit and sets it to false
  let rambo_bit 0                                                                    ; this creates a local variable calles rambo_bit and sets it to 0

  ask rambo in-cone zombies_vision_radius zombies_vision_angle [                     ; this sets up a vision cone with the parameters from zombies_vision_radius zombies_vision_angle to detects rambo
    set color green                                                                  ; this sets the color of the rambo detected within the vision code of the zombie to green
    set seen true                                                                    ; this sets the local variable called seen to true indicating that a rambo has been seen
  ]

  ask rambo in-radius radius [                                                       ; this sets up a radius around the zombie to the value of the global variable radius which we are using for collision detection with rambo
    set bit true                                                                     ; this sets the local variable called bit to true indicating that a rambo has collided with the zombie
    set rambo_bit who                                                                ; this sets the local variable called rambo_bit to the individual who
  ]

  if seen = true [                                                                   ; if seen is true then...
    face min-one-of rambo [distance myself]                                          ; checks if human is near
    set color white                                                                  ; set color of zombie to white
  ]

  if bit = true [                                                                    ; if bit is true then...
    ask rambos rambo_bit [                                                           ; this asks all of the rambos in the population to do what is in the brackets
      set death_by_zombie death_by_zombie + 1                                        ; this increments the cause of death by zoombie by one in order for plotting
      set breed zombies                                                              ; this sets the breed of the dead rambo to a zombie
      set shape "person"                                                             ; this sets the shape of the dead rambo to a person
    ]
    set color green                                                                  ; set color of zombie to green
  ]
end


;;;;;;;;;;;;;;;;;
;; ENVIRONMENT ;;
;;;;;;;;;;;;;;;;;

to reset-patch-colour                                                                ; this creates a function called reset-patch-colour
  ask patches [                                                                      ; this asks all of the patches in the population to do what is in the brackets
    if solid = false [                                                               ; if solid is true then...
      set pcolor current_color                                                       ; this sets the color of each patch to black
    ]
  ]

  ifelse daytime = true [                                                            ; if global variable daytime is true...
    set current_color current_color - color_adjust                                   ; adjust global variable current_color using color_adjust variable
  ][                                                                                 ; otherwise...
    set current_color current_color + color_adjust                                   ; adjust global variable current_color using color_adjust variable
  ]
end

to grow-food                                                                         ; this creates a function called grow-food
  create-food number_of_foods [                                                      ; this creates the number of foods that your global variable states
    setxy random-xcor random-ycor                                                    ; this sets the starting position of the food to a random location in the world
    set color green                                                                  ; this sets the color of the food to green
    set size 7                                                                       ; this sets the size of the food to 7
    set shape "food"                                                                 ; this sets the shape of the food to a food
    set amount random 100                                                            ; this sets the amount of foods to a random value up to 100
  ]
end

to spawn-guns                                                                        ; this creates a function called spawn-guns
  create-gun number_of_guns [                                                        ; this creates the number of guns that your global variable states
    setxy random-xcor random-ycor                                                    ; this sets the starting position of the guns to a random location in the world
    set size 10                                                                      ; this sets the size of the guns to 10
    set shape "gun"                                                                  ; this sets the shape of the guns to a gun
    set amount random 100                                                            ; this sets the amount of guns to a random value up to 100
  ]
end

to spawn-more-resources                                                              ; this creates a function called spawn-more-resources
  if (remainder ticks 100 = 0) [                                                     ; this checks if the remainder is 0 when the ticks is 100
    if respawn_food = true [                                                         ; this will switch on the respawn food if the switch is set to true
      ask patch random-xcor random-ycor [                                            ; ask a patch in a random location (x, y coordinate) to do the following...
        sprout-food number_of_foods [grow-more-food]                                 ; sprout (create new) food (number_of_foods) then call the grow-more-food function to set the parameters of the food
      ]
    ]

    if respawn_gun = true [                                                          ; this will switch on the respawn gun if the switch is set to true
      ask patch random-xcor random-ycor [                                            ; ask a patch in a random location (x, y coordinate) to do the following...
        sprout-gun number_of_guns [grow-more-gun]                                    ; sprout (create new) gun (number_of_guns) then call the grow-more-gun function to set the parameters of the gun
      ]
    ]

    ifelse daytime = true [                                                          ; if global variable daytime is true...
      set daytime false                                                              ; set global variable daytime to false
    ][                                                                               ; otherwise...
      set daytime true                                                               ; set global variable daytime to true
    ]
  ]
end

to grow-more-food                                                                    ; this creates a function called grow-more-food
  setxy random-xcor random-ycor                                                    ; this sets the starting position of the food to a random location in the world
  set color green                                                                    ; this sets the color of the food to green
  set size 7                                                                         ; this sets the size of the food to 7
  set shape "food"                                                                   ; this sets the shape of the food to a food
  set amount random 100                                                              ; this sets the amount of foods to a random value up to 100
end

to grow-more-gun                                                                     ; this creates a function called grow-more-gun
  setxy random-xcor random-ycor                                                      ; this sets the starting position of the guns to a random location in the world
  set size 10                                                                        ; this sets the size of the gun to 10
  set shape "gun"                                                                    ; this sets the shape of the gun to a gun
  set amount random 100                                                              ; this sets the amount of guns to a random value up to 100
end

to draw-building                                                                     ; this creates a function called draw-building
  ask patches [                                                                      ; this selects all of the patches to follow a command
    set solid false                                                                  ; this sets the patch variable solid to false for all patches
  ]
  ask patches with [ pxcor >= -20 and pxcor <= 20 and pycor >= -20 and pycor <= 20][ ; this selects only patches that meet the parameters
    set pcolor white                                                                 ; this sets the color of all of the patches selects to white
    set solid true                                                                   ; this sets the variable solid to true for all of the patches selected
  ]
end

to detect-wall                                                                       ; this creates a function called detect-wall
  if [solid] of patch-ahead 1 = true [                                               ; if patch varible of 1 patch ahead is true then...
    rt 180                                                                           ; turn around to opposite direction
  ]
end

to check-winner                                                                      ; this creates a function called check-winner
  if count humans + count rambo = 0 [                                                ; if the number of humans + number of rambos = 0 then...
    user-message (word "The Zoobies have won!!! With "count zombies " zombies left.") ; output the message
  ]

  if count zombies = 0 [                                                             ; if the number of zombies = 0 then...
    user-message (word "The humans have won!!! With "(count humans + count rambo) "humans left.") ; output the message
  ]
end
@#$#@#$#@
GRAPHICS-WINDOW
385
10
995
621
-1
-1
2.0
1
10
1
1
1
0
1
1
1
-150
150
-150
150
1
1
1
ticks
30.0

SLIDER
4
149
176
182
number_of_humans
number_of_humans
1
1000
993.0
1
1
NIL
HORIZONTAL

SLIDER
197
150
369
183
number_of_zombies
number_of_zombies
1
1000
1.0
1
1
NIL
HORIZONTAL

SLIDER
4
182
176
215
humans_speed
humans_speed
1
10
2.0
1
1
NIL
HORIZONTAL

SLIDER
197
183
369
216
zombies_speed
zombies_speed
1
10
1.0
1
1
NIL
HORIZONTAL

SLIDER
4
214
176
247
humans_vision_radius
humans_vision_radius
0
50
17.0
1
1
NIL
HORIZONTAL

SLIDER
4
246
176
279
humans_vision_angle
humans_vision_angle
0
180
48.0
1
1
NIL
HORIZONTAL

SLIDER
197
215
369
248
zombies_vision_radius
zombies_vision_radius
0
50
0.0
1
1
NIL
HORIZONTAL

SLIDER
197
247
369
280
zombies_vision_angle
zombies_vision_angle
0
90
0.0
1
1
NIL
HORIZONTAL

SWITCH
114
490
256
523
show_vis_cone
show_vis_cone
1
1
-1000

BUTTON
162
33
267
66
go (forever)
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
0

BUTTON
96
33
162
66
NIL
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

PLOT
1016
57
1406
207
Model stats
Time
Quantity
0.0
20.0
0.0
20.0
true
true
"" ""
PENS
"Humans" 1.0 0 -1184463 true "" "plot count humans + count rambo"
"Zombies" 1.0 0 -2674135 true "" "plot count zombies"

SLIDER
195
396
367
429
number_of_guns
number_of_guns
0
1000
1000.0
1
1
NIL
HORIZONTAL

MONITOR
1181
10
1245
55
Humans
count humans
0
1
11

MONITOR
1255
10
1321
55
Zombies
count zombies
0
1
11

TEXTBOX
55
121
205
139
Humans
11
0.0
1

TEXTBOX
268
118
418
136
Zombies
11
0.0
1

TEXTBOX
150
330
300
348
Environment
11
0.0
1

SLIDER
195
363
367
396
number_of_foods
number_of_foods
0
100
100.0
1
1
NIL
HORIZONTAL

MONITOR
1109
10
1172
55
Rambos
count rambo
0
1
11

BUTTON
127
73
235
106
go 500 ticks
go if (ticks = 500) [\nstop\n]
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SWITCH
33
366
173
399
respawn_food
respawn_food
0
1
-1000

SWITCH
33
398
173
431
respawn_gun
respawn_gun
0
1
-1000

PLOT
1016
206
1406
356
Resources
Time
Nº of resources
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"Food" 1.0 0 -8732573 true "" "plot count food"
"Gun" 1.0 0 -8431303 true "" "plot count gun"

PLOT
1016
355
1406
505
Deaths
Time
Nº of Deaths
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"Death by starvation" 1.0 0 -13791810 true "" "plot death_by_starvation"
"Killed by zombie" 1.0 0 -817084 true "" "plot death_by_zombie"

SWITCH
114
457
256
490
show_col_rad
show_col_rad
1
1
-1000

@#$#@#$#@
## WHAT IS IT?

It's an agent-based model to explore the potential outcomes of a Zombiism epidemic.
"In this agent-model, we trying to demonstrate what could happen in the apocalypse with a spread of infectious disease, infecting humans that transform in zombies.
In this model, we gave various options that can be put in the environment to see what could happen. Like for example, the number of zombies and the number of humans that exist in the environment."

## RULES FOR HUMANS

Humans have to make choices to whether or not they are willing to risk running for food or gun while zombies are nearby.
Humans with 15 years old or more could have a gun and became rambo. Rambos have some ability to defend themselves against individual zombies, but a herd is likely to kill them quickly.
Once humans starve to death, they became zombies.

## RULES FOR ZOMBIES

Zombies hunt humans using vision. Each tick, zombies look for humans using their relatively short-ranged vision. If they see a human, they will follow the closest one.
Zombies will bite the humans, converting them to a zombie who will then join the hunt for humans.

## RULES FOR THE ENVIRONMENT

If the switch is set to true, every 100 ticks the environment will spawn a number of food and guns piles. Placement of these piles is random, and the number of piles is somewhat random as well.

## HOW TO USE IT

1. Set the initial number of humans and zombies.
2. Set the initial speed for humans and zombies.
3. Set the initial vision for humans and zombies.
4. Set the initial food and guns available for humans.
5. Set the initial value to respawn food and/or guns.
6. Click Setup to populate the simulation grid.
7. Click Go to set the agents in motion.

## THINGS TO NOTICE

Zombies seek humans.
Humans run away if they see a zombie.
If a human gets a gun, it becomes rambo.
Rambo can shoot a zombie.

## THINGS TO TRY

Start with one zombie.
Slow zombies sometimes catch more humans.

## EXTENDING THE MODEL

Super zombies. Simulate the bullet path.

## NETLOGO FEATURES

The simulation runs smoother if the model is set to ticks update instead of an update on continuous.
The figure "person soldier" needs to be downloaded from the Netlogo Library.

## RELATED MODELS

None.

## CREDITS AND REFERENCES

Manuel Gomes Rosmaninho, Computer Science Student, University of Hertfordshire - UK
Roberto Figueiredo, Computer Science Student, University of Hertfordshire - UK

This model was developed as a part of Artificial Intelligence coursework for the University of Hertfordshire.
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

food
false
0
Polygon -7500403 true true 30 105 45 255 105 255 120 105
Rectangle -7500403 true true 15 90 135 105
Polygon -7500403 true true 75 90 105 15 120 15 90 90
Polygon -7500403 true true 135 225 150 240 195 255 225 255 270 240 285 225 150 225
Polygon -7500403 true true 135 180 150 165 195 150 225 150 270 165 285 180 150 180
Rectangle -7500403 true true 135 195 285 210

gun
true
1
Rectangle -7500403 true false 46 130 270 150
Rectangle -6459832 true false 172 130 215 150
Rectangle -6459832 true false 165 139 195 150
Rectangle -6459832 true false 46 130 90 150
Rectangle -6459832 true false 46 141 105 164
Rectangle -6459832 true false 22 163 86 196
Rectangle -6459832 true false 29 145 73 170
Rectangle -7500403 true false 33 118 46 144
Rectangle -6459832 true false 34 178 71 209

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

person soldier
false
0
Rectangle -7500403 true true 127 79 172 94
Polygon -10899396 true false 105 90 60 195 90 210 135 105
Polygon -10899396 true false 195 90 240 195 210 210 165 105
Circle -7500403 true true 110 5 80
Polygon -10899396 true false 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Polygon -6459832 true false 120 90 105 90 180 195 180 165
Line -6459832 false 109 105 139 105
Line -6459832 false 122 125 151 117
Line -6459832 false 137 143 159 134
Line -6459832 false 158 179 181 158
Line -6459832 false 146 160 169 146
Rectangle -6459832 true false 120 193 180 201
Polygon -6459832 true false 122 4 107 16 102 39 105 53 148 34 192 27 189 17 172 2 145 0
Polygon -16777216 true false 183 90 240 15 247 22 193 90
Rectangle -6459832 true false 114 187 128 208
Rectangle -6459832 true false 177 187 191 208

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.1.1
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
0
@#$#@#$#@
