; PANDEMIC Z

; ----- BREEDS -----
breed [humans human]
breed [zombies zombie]
breed [resources resource]

; ----- GLOBALS -----
globals [
  day
  resource-scarcity
]

; ----- AGENT PROPERTIES -----
humans-own [
  ; Physical
  energy
  speed
  strength
  state
  vision-range

  ; Resources
  resource-inventory

  ; Psychological
  stress-level
  trust-level
  cooperation-level

  ; Skills
  skill-combat
  skill-gathering

  ; Role
  role
  last-action
  combat-actions
  gathering-actions

  ; Zombiefication
  infection-timer
]

zombies-own [
  health             ; 0-100
  speed              ; typically slower than humans
  strength           ; determines damage to humans
  state              ; "wandering", "chasing", "feeding", "following-horde", "breaking-in"
  vision-range       ; typically poor
  hearing-range      ; typically good
  satiation          ; increases when feeding, decreases over time

  target-human       ; which human this zombie is chasing
  horde-leader?      ; is this zombie leading a horde chase
  following-zombie   ; which zombie this one is following in horde
  chase-timer        ; how long they've been chasing current target

  age-ticks          ; how long this zombie has existed
  decay-rate         ; individual decay speed (varies by zombie)
  max-lifespan       ; when this zombie will die from decay (3-5 years in ticks)

  ; SHELTER BREAKING PROPERTIES
  target-shelter     ; which shelter this zombie is trying to break into
  break-progress     ; progress on breaking into current shelter
]

resources-own [
  amount
]

patches-own [
  resource-level     ; amount of available resources (0-100)
  is-shelter         ; boolean if patch is shelter
  zombie-scent       ; for zombie tracking of humans

  ; NEW SHELTER PROPERTIES
  shelter-integrity  ; 0-100, how intact the shelter is
  being-broken?      ; boolean, is zombie currently breaking in
  break-timer        ; ticks needed to break in completely
  max-break-time     ; total time needed to break in (varies by shelter quality)
]

; ----- SETUP PROCEDURES -----
to setup
  clear-all
  setup-environment
  setup-humans
  setup-zombies
  setup-resources
end

; Create the environment with varied terrain
to setup-environment

  ; Initialize all patches with base properties first
  ask patches [
    set resource-level 0
    set is-shelter false
    set zombie-scent 0

    ; Initialize shelter properties for all patches
    set shelter-integrity 20
    set being-broken? false
    set break-timer 0
    set max-break-time 0
  ]

  ; Load the urban map from file
  file-open "map.txt"
  let y max-pycor

  while [not file-at-end?] [
    let row file-read-line
    let x min-pxcor
    let i 0

    ; Process each character in the row without explode function
    while [i < length row] [
      let char substring row i (i + 1)
      ask patch x y [
        if char = "W" [       ; Blank spaces
          set pcolor black
        ]
        if char = "G" [       ; Resource areas
          set resource-level 15 + random-float 25   ; High resources (15-40)
          set pcolor scale-color lime resource-level 0 50
        ]
        if char = "O" [       ; Shelters
          ; Initialize shelters with full properties
          set is-shelter true
          set pcolor orange

          set max-break-time (shelter-integrity / 2) + random 30
          set being-broken? false
          set break-timer 0
        ]
      ]
      set x x + 1
      set i i + 1
    ]
    set y y - 1
  ]

  file-close

  ; Initialize resources in resource areas
  setup-resources

  ; Set initial game values
  set day 1
  set resource-scarcity 50  ; Medium scarcity to start

  reset-ticks
end

to setup-humans
  create-humans initial-human-population [
    set shape "person"
    set color white
    set size 1.5
    move-to one-of patches with [pcolor = orange and not any? humans-here]

    ; Initialize properties
    ; Physical
    set energy 75 + random 25
    set speed 0.5 + random-float 0.5
    set strength  3 + random 7
    set state "wandering"
    set vision-range 3 + random 2

    ; Resources
    set resource-inventory  20 + random 30

    ; Psychological
    set stress-level 30 + random 70
    set trust-level 30 + random 70
    set cooperation-level 30 + random 70

    ; Skills
    set skill-combat 10 + random 20
    set skill-gathering 10 + random 20

    ; Role
    specialize-role
    set last-action "none"
    set combat-actions 0
    set gathering-actions 0

    ; Not infected at start
    set infection-timer 0
  ]
end

to setup-zombies
  create-zombies initial-zombie-population [
    set shape "person"
    set color red
    set size 1.5
    move-to one-of patches with [
      pxcor > 0 and pycor < 0 and  ; Positive X, negative Y coordinates (lower right)
      not any? turtles-here
    ]

    set health 75 + random 25
    set speed 0.2 + random-float 0.8
    set strength 7 + random 3
    set state "wandering"
    set vision-range 2 + random 3
    set hearing-range 3 + random 2
    set satiation 0

    set target-human nobody
    set horde-leader? false
    set following-zombie nobody
    set chase-timer 0

    set age-ticks 0
    set decay-rate 0.01 + random-float 0.04
    set max-lifespan 1000 + random 3000
  ]
end

; Setup resources only in designated resource areas (green patches)
to setup-resources
  ask patches with [pcolor >= green and pcolor <= lime] [
    ; Each resource patch has a chance to contain a resource based on resource-level
    let spawn-chance (resource-level / 40) * 70  ; Higher resource-level = higher spawn chance
    if random-float 100 < spawn-chance [
      sprout 1 [
        set breed resources
        set color yellow
        set shape "circle"
        set size 0.8
        set amount 10 + random 20
      ]
    ]
  ]
end

; ----- MAIN PROCEDURES -----
to go
  ; Stop simulation if no more humans
  if not any? humans [stop]

  if ticks mod 50 = 0 [
    set day day + 1
  ]

  ; Respawn resources less frequently
  ; if ticks mod 150 = 0 [  ; Every 10 ticks
  ;  respawn-resources
  ; ]

  ask humans [human-behavior]

end

to human-behavior
  ; 1. Metabolism & health checks first
  update-energy-level
  death-check

  ; 2. Update stress early, since stress affects behavior
  update-stress

  ; 3. If stress is very high, prioritize hiding and recovering stress
  if stress-level > 80 [
    hide-and-recover
    stop  ;; do nothing else this tick
  ]

  ; 4. If energy is sufficient, do main tasks
  if energy > 20 [
    perform-task
    cooperate-with-others
  ]

  ; 5. If resources are low, ask for resources (might involve cooperation)
  if resource-inventory < 30 [
    ask-for-resources
  ]

  ; 6. Consume resources last, after tasks and cooperation
  consume-resources

  ; 7. Update trust and cooperation levels based on last actions
  update-trust-cooperation

  ; 8. Movement or wandering as fallback or end-of-turn activity
  wander
end


to update-energy-level
  ;; Default passive drain
  let drain 0.1

  ;; Adjust based on last action
  if last-action = "wander"         [ set drain 0.1 ]
  if last-action = "run"            [ set drain 1.0 ]
  if last-action = "hide"           [ set drain 0.1 ]
  if last-action = "defend"         [ set drain 1.2 ]
  if last-action = "attack"         [ set drain 1.2 ]

  ;; Apply the drain, but never go below 1
  set energy max (list 1 (energy - drain))
end

to update-trust-cooperation
  ; Base constant increase each tick (small)
  set trust-level min (list 100 (trust-level + 0.05))
  set cooperation-level min (list 100 (cooperation-level + 0.05))

  ; Positive actions
  if last-action = "share" [
    set trust-level min (list 100 (trust-level + 5))
    set cooperation-level min (list 100 (cooperation-level + 5))
  ]

  if last-action = "receive" [
    set trust-level min (list 100 (trust-level + 3))
    set cooperation-level min (list 100 (cooperation-level + 3))
  ]

  if last-action = "defend" [
    set trust-level min (list 100 (trust-level + 4))
    set cooperation-level min (list 100 (cooperation-level + 4))
  ]

  if last-action = "dismissive" [
    set trust-level max (list 0 (trust-level - 5))
    set cooperation-level max (list 0 (cooperation-level - 5))
  ]

  ;; Reset to prevent repeated adjustments
  set last-action "none"
end

to update-stress
  set stress-level min (list 100 (stress-level + 0.1))

  let zombies-nearby count zombies in-radius vision-range
  let on-shelter? (pcolor = orange or is-shelter)

  if zombies-nearby > 0 [
    ;; Increase stress if zombies nearby
    set stress-level min (list 100 (stress-level + 2 * zombies-nearby))
  ]
  if on-shelter? [
    ;; Decrease stress gradually if on shelter
    set stress-level max (list 0 (stress-level - 5))
  ]
end

to death-check
  if energy <= 0 [
    set state "corpse"
    set color gray
    die
  ]
end

to specialize-role
  ifelse (skill-combat > skill-gathering) [
    set role "defender"
    set color blue
  ][
    set role "gatherer"
    set color pink
  ]
end

; Allow humans to switch roles based on skill, needs, and environment
; NOTE: When does it evolve?
to adapt-role
  if (role = "gatherer" and skill-combat > skill-gathering + 1) [ set role "defender"]
  if (role = "defender" and skill-gathering > skill-combat + 1) [ set role "gatherer" ]
end

to perform-task
  if any? zombies in-radius vision-range [
    if role = "defender" [
      attack-zombie
    ]
  ]

 if role = "gatherer" [
   gather-resources
 ]
end

to attack-zombie
  let visible-zombies zombies in-radius vision-range

  if any? visible-zombies [
    let target-zombie min-one-of visible-zombies [distance myself]
    face target-zombie

    ifelse distance target-zombie > 1 [
      fd speed * 1.2  ; Move closer if not yet in range
    ] [
      ; Attack only if probability check succeeds
      ; NOTE: And if there is enough energy
      perform-attack target-zombie
      set last-action "attack"
    ]
  ]
end

; Gather resource when the area is safe and if you don't have maximum resource invetory (100) yet
; Otherwise, run-hide
to gather-resources
  let nearby-resources resources in-radius vision-range
  if any? nearby-resources [
    ; Check safety condition
    let zombies-nearby zombies in-radius vision-range
    let defenders-nearby humans with [role = "defender"] in-radius vision-range

    ifelse any? zombies-nearby and not any? defenders-nearby [
      let target-resource one-of nearby-resources
      face target-resource

      ; Move forward toward resource but only if not already close
      ifelse distance target-resource > 1 [
        fd speed
      ] [
        ; Close enough to gather
        let resource-amount [amount] of target-resource
        let space-left 100 - resource-inventory

        if space-left > 0 [
          let gathered-amount min (list resource-amount space-left)
          set resource-inventory resource-inventory + gathered-amount

          ask target-resource [ die ]
          set last-action "gather"
        ]
      ]
    ][
      ; run-hide
    ]
  ]
end

; Consume resources when energy is low
to consume-resources
  if energy < 30 and resource-inventory >= 10 [
    set resource-inventory resource-inventory - 10
    set energy energy + 10  ; assume 10 units restore 20 energy
    if energy > 100 [ set energy 100 ] ; cap energy at 100
    set last-action "consume"
  ]
end

; Ask for resources if trust level is high
to ask-for-resources
  if trust-level > 71 [
    let potential-donors other humans in-radius 2 with [resource-inventory > 30]

    if any? potential-donors [
      let donor one-of potential-donors
      ask donor [
        give-resources-to myself
      ]
      set last-action "ask"
      stop
    ]
  ]
end


to give-resources-to [recipient]
  if trust-level > 71 and cooperation-level > 71 [
    let spare resource-inventory - 30
    if spare > 0 [
      let needed 100 - [resource-inventory] of recipient
      let max-give min (list spare needed)
      let to-give random (max-give + 1)

      if to-give > 0 [
        set resource-inventory resource-inventory - to-give
        ask recipient [
          set resource-inventory resource-inventory + to-give
          set last-action "receive"
        ]
        set last-action "share"
        stop
      ]
    ]
  ]
end


to cooperate-with-others
  if trust-level > 71 and cooperation-level > 71 [

    ;; ===== RESOURCE SHARING =====
    let nearby-humans other humans in-radius 2 with [resource-inventory < 30]
    if any? nearby-humans [
      let needy one-of nearby-humans

      ;; Random chance to help vs ignore
      ifelse random-float 100 < 85 [ ; 85% chance to help
        give-resources-to needy
        stop
      ] [
        set last-action "dismissive"
        ;; optionally print or log it
        stop
      ]
    ]

    ;; ===== DEFEND OTHERS =====
    if skill-combat > skill-gathering [
      let zombies-nearby zombies in-radius vision-range
      let humans-nearby other humans in-radius vision-range
      let endangered one-of humans-nearby with [
        any? zombies in-radius 1
      ]

      if endangered != nobody and any? zombies-nearby [
        ;; Random chance to defend
        if random-float 100 < 85 [ ; 85% chance to defend
          let target-zombie min-one-of zombies-nearby [distance endangered]
          face target-zombie

          if distance target-zombie > 1 [
            fd speed * 1.3
          ]
          ifelse random-float 100 < 80 [
            perform-attack target-zombie
            set last-action "defend"
            stop
          ] [
            set last-action "dismissive"
            stop
            ]
        ]
      ]
    ]
  ]
end

; MOVEMENT
to wander
  ; Simple random walk
  rt random 50 - random 50
  fd speed * 0.5
  set last-action "wander"
end

to run-away
  let nearest-zombie min-one-of zombies [distance myself]

  if nearest-zombie != nobody [
    face nearest-zombie
    rt 180                ; Turn and run opposite direction
    fd speed * 1.4        ; Move faster than usual
    set last-action "run"
    stop
  ]
end

to hide-and-recover
  let shelter-radius 2
  let current-patch patch-here

  ;; Check if already at a shelter patch
  ifelse pcolor = orange or is-shelter [
    ;; Reduce stress gradually while staying sheltered
    set stress-level max (list 0 (stress-level - 5))

    ;; If stress is low enough, wander again
    ifelse stress-level <= 20 [
      set last-action "recovered"
      wander
      stop
    ] [
      set last-action "recovering"
      ;; Stay put, do nothing else this tick
      stop
    ]
  ]
  ;; Otherwise try to move to a shelter nearby
   [
    let shelters patches in-radius shelter-radius with [pcolor = orange or is-shelter]
    ifelse any? shelters [
      move-to one-of shelters
      set last-action "hide"
      stop
    ] [
      ;; No shelter found, wander or run away (depends on context)
      wander
      stop
    ]
  ]
end

to perform-attack [target]
  if random-float 40 < skill-combat [
    ask target [
      set health health - [strength] of myself
      if health <= 0 [ die ]
    ]
  ]
end






@#$#@#$#@
GRAPHICS-WINDOW
211
10
882
552
-1
-1
13.0
1
10
1
1
1
0
1
1
1
-25
25
-20
20
1
1
1
ticks
30.0

BUTTON
23
35
90
68
setup
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

SLIDER
67
167
277
200
initial-human-population
initial-human-population
0
100
15.0
1
1
NIL
HORIZONTAL

SLIDER
79
222
291
255
initial-zombie-population
initial-zombie-population
0
100
17.0
1
1
NIL
HORIZONTAL

BUTTON
68
99
132
133
NIL
go
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

@#$#@#$#@
## WHAT IS IT?

(a general understanding of what the model is trying to show or explain)

## HOW IT WORKS

(what rules the agents use to create the overall behavior of the model)

## HOW TO USE IT

(how to use the model, including a description of each of the items in the Interface tab)

## THINGS TO NOTICE

(suggested things for the user to notice while running the model)

## THINGS TO TRY

(suggested things for the user to try to do (move sliders, switches, etc.) with the model)

## EXTENDING THE MODEL

(suggested things to add or change in the Code tab to make the model more complicated, detailed, accurate, etc.)

## NETLOGO FEATURES

(interesting or unusual features of NetLogo that the model uses, particularly in the Code tab; or where workarounds were needed for missing features)

## RELATED MODELS

(models in the NetLogo Models Library and elsewhere which are of related interest)

## CREDITS AND REFERENCES

(a reference to the model's URL on the web if it has one, as well as any other necessary credits, citations, and links)
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
NetLogo 6.4.0
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
