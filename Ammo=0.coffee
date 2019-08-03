class Body
	alive:	true

	# --Methods goes here.
	constructor: (@sprite_id, @scene, x, y, trail_id) ->
		# Init setup.
		@model		= @scene.physics.add.existing @scene.add.container x, y, [@scene.add.image(0, 0, @sprite_id)]
		@requiem	= @scene.sound.add("explode:#{@sprite_id}").on 'complete', (snd) -> snd.destroy()
		@model.self	= @
		# Trail setup.
		if trail_id?
			@trail = @scene[trail_id].createEmitter cfg =
				speed: 100, scale: { start: 0.02, end: 0 },	blendMode: 'ADD', on: false, angle: () => @model.angle + 90
			.startFollow @model, true, 0.05, 0.05

	orient: (dest, speed = 200) ->
		angle = Phaser.Math.Angle.Between(@model.x, @model.y, dest.x, dest.y﻿)﻿
		delta = @model.rotation - angle - 3.14 * (if angle > 3.14 / 2 then -1.5 else 0.5)
		if Math.abs(delta) > 3.14 then delta = -delta
		@model.body.setAngularVelocity -(if Math.abs(delta) > speed/1000 then Math.sign(delta) * speed else delta)

	propel: (impulse) ->
		@scene.physics.velocityFromRotation(@model.rotation - 3.14 / 2, impulse, @model.body.acceleration)
		@trail?.start()

	volume: (hear = 1000) ->
		volume: Math.max 0,
			(hear - Phaser.Math.Distance.Between(@scene.player.model.x, @scene.player.model.y, @model.x, @model.y))/hear

	explode: (magnitude = 50) ->
		@explosion  = @scene.explode.createEmitter
			speed: { min: magnitude * 0.9, max: magnitude * 1.1 }, scale: { start: 0.1, end: 0 }, blendMode: 'ADD'
		.explode(magnitude * 2, @model.x, @model.y)
		@model.destroy()
		@trail?.stopFollow().stop()
		@requiem?.play @volume()
		@alive = false

	update: () ->
		@scene.physics.world.wrap @model, 0
		@trail?.stop()
		@trail?.followOffset.x = -@model.body.acceleration.x / 10
		@trail?.followOffset.y = -@model.body.acceleration.y / 10
# -------------------- #
class Player extends Body
	trashed: 0

	# --Methods goes here.
	constructor: (scene, cfg, x = 0, y = 0) ->
		# Body setup.
		super 'pship', scene, x, y, 'jet'
		@scene.spacecrafts.add @model
		@model.setScale 0.15, 0.15
		@model.body.setMaxVelocity(100).setOffset(-65, -45).setSize(130, 130).setDrag(0.95).useDamping = true
		# Custom jet trail.
		@trail.setSpeed({ min: 50, max: -50}).setFrequency(0, 2).setScale({ start: 0.03, end: 0 })
		# Crosshair
		@target = @scene.add.container(0, 0).setDepth 3
		@target.add [
			@scene.add.image(0, 0, 'dest').setScale(0.08, 0.08).setAlpha(0.9)
			@scene.add.line(cfg.width / 2, 0, 0, 0, cfg.width * 3, 0, 0x50C878, 0.1),
			@scene.add.line(0, -cfg.height / 2, 0, 0, 0, cfg.height * 3, 0x50C878, 0.1)]
		@scene.tweens.add
			targets: @target.first, scaleX: 0.17, scaleY: 0.17, ease: 'Power1'
			duration: 300, repeat: -1, yoyo: true, repeatDelay: 500
		# Finalization.
		@scene.cameras.main.startFollow @model, true, 0.05, 0.05
		@target.visible = false
		@hud = @scene.add.container 15, 15, (for color in ['gray', 'slategray']
			lbl = @scene.add.text 0, 0, '', {fontFamily: 'Saira Stencil One', fontSize: 25, color: color})
		.setScrollFactor(0).setDepth(2)
		.add(@scene.add.text 0, cfg.height-65, '', {fontFamily: 'Saira Stencil One', fontSize: 25, color: '#cb4154'})
		lbl.setShadow(0, 0, "black", 7, true, true) for lbl in @hud.list

	explode: () ->
		super()
		@hud.destroy()
		@target.destroy()
		@scene.cameras.main.fadeOut(1000)
		@scene.cameras.main.shake()

	notedeath: () ->
		return unless @alive
		@trashed++
		@trash_anim = @scene.tweens.add cfg =
			targets: @hud.list[1], scaleY: 0.0, yoyo: true, duration: 300, ease: 'Power1'

	update: () ->
		super()
		# Crosshair updating.
		Object.assign @target, @scene.cameras.main.getWorldPoint @scene.input.activePointer.position.x,
			@scene.input.activePointer.position.y
		@target.first.rotation -= 0.025
		@orient @target
		@model.body.setAcceleration(0)
		# Controls.
		@target.first.setTint if @scene.input.activePointer.isDown
			@propel(200)
			0x00FFFF
		else 0x708090
		# HUD update.
		@hud.first.setColor (if 0 < @trash_anim?.progress < 1 then 'crimson' else @hud.last.scaleY = 1; 'gray')
		for lbl, idx in @hud.list[0..1]
			if idx is 0 or not (0 < @trash_anim?.progress < 0.5) then lbl.setText "Trashed: #{@trashed}"
		@hud.last.setText("Threat: #{'⬛'.repeat(@scene.enemies)}")
		# Finalization.
		@target.visible = true
		@alive
# -------------------- #
class Missile extends Body
	fuel:	1000
	fused:	false

	# --Methods goes here.
	constructor: (scene, emitter, @target) ->
		super 'rocket', scene, emitter.model.x, emitter.model.y, 'jet'
		@model.setScale(0.15, 0.05).rotation = @scene.physics.accelerateToObject(@model, @target.model, 0) + 3.14 / 2
		@model.body.setMaxVelocity(110).setSize(100, 300).setOffset(-50, -150)
		@emitter = emitter

	explode: () ->
		super()

	orient: (dest, speed = 400) ->
		super dest, speed

	update: () ->
		super()
		if @fuel-- > 0
			@orient @target.model
			@propel(200)
			@fused = true if not @fused and not @scene.physics.world.overlap(@model, @emitter.model)
		else if @fuel < -30 then @explode()
		if @alive and @fused then @scene.physics.world.overlap @model, @scene.spacecrafts, (rkt, tgt) ->
			rkt.self.explode()
			tgt.self.explode()
		@alive
# -------------------- #
class MissileBase extends Body
	constructor: (scene, x, y) ->
		# Model setup
		super 'mbase', scene, x, y
		@model.setScale(0.0, 0.2).alpha = 0
		@model.body.setOffset(-200, -200).setSize(400, 400)
		# Additional setup.
		@scene.spacecrafts.add(@model)
		@scene.enemies++
		@reload	= 0
		# Missile silo
		@silo	= @scene.steam.createEmitter cfg =
			speed: { min: 50,		max: 100 }
			scale: { start: 0.1,	end: 0.05 }
			alpha: { start: 1,		end: 0 }
			frequency: -1
			blendMode: 'ADD'
		# Appearing.
		@teleport = @scene.tweens.add cfg =
			targets: @model,
			scaleX: 0.2
			alpha: 1 # { start: 0, end: 1}
			duration: 1000,
			ease: 'Sine.easeInOut'

	explode: () ->
		super 75
		@scene.enemies--
		@scene.player.notedeath()

	update: () ->
		super()
		return true unless @teleport.progress is 1
		@model.body.setAngularVelocity(100)
		if @reload++ is 100
			@scene.pending.push new Missile @scene, @, @scene.player
			@silo.explode(80, @model.x, @model.y)
			@scene.sound.add("steam").on('completed', (snd) -> snd.destroy()).play(@volume())
			@reload = 0
		@scene.physics.world.overlap @model, @scene.player.model, (bse, plr) ->
			bse.self.explode()
			plr.self.explode()
		@alive
# -------------------- #
class Game
	self = null
	rnd: Phaser.Math.Between

	# --Methods goes here.
	constructor: (width = 1024, height = 768) ->
		window.resizeTo Math.max(window.innerWidth, width+20), Math.max(window.innerHeight, height+45)
		window.moveTo (screen.width-window.outerWidth) / 2, (screen.height-window.outerHeight) / 2
		@app = new Phaser.Game
			type: Phaser.WEBGL, width: width, height: height, parent: 'vp'
			scale: {mode: Phaser.Scale.EXACT_FIT, autoCenter: Phaser.Scale.CENTER_BOTH}
			scene: {preload: @preload, create: @create.bind(@), update: @update.bind(@)}
			physics: 
				default: 'arcade'
				#arcade:
					#debug: true
		self = @

	preload: () ->
		self.scene = @
		@load.setPath "res/"
		for kind in ['rocket', 'mbase', 'pship']
			@load.image kind,				"#{kind}.png"
			@load.audio "explode:#{kind}",	"Explosion_#{kind}.wav"
		@load.image 'space',	'space.jpg'
		@load.image 'jet',		'flash00.png'
		@load.image 'steam',	'steam00.png'
		@load.image 'dest',		'dest.png'
		@load.image 'explode',	'explosion00.png'
		@load.audio 'steam',	"steam.wav"
		@load.audio "ambient:#{idx}", "Track#{idx}.ogg" for idx in [1..3]			

	create: () ->
		# Init setup.
		cfg		= @app.config
		@space	= @scene.add.tileSprite cfg.width / 2, cfg.height / 2, cfg.width*2, cfg.height*2, 'space'
		@scene.spacecrafts = @scene.physics.add.group()
		@space.setScrollFactor(0)
		# Particle setup.
		@scene[matter] = @scene.add.particles(matter) for matter in ['jet', 'explode', 'steam']
		@scene.steam.setDepth(1)
		# SFX switcher.
		@muter = @scene.add.text @app.config.width - 60, 15, "", {fontSize: 35, color: 'Cyan'}
		@muter.setScrollFactor(0).setInteractive().setDepth(2).state = 0
		@muter.on 'pointerdown', (() ->
			@scene.sound.setMute @state; @setText ["🔈", "🔊"][@state = 1 - @state]).bind @muter
		@muter.emit('pointerdown')
		# Ambient music.
		@track_list	= []
		random = (() -> @[Phaser.Math.Between 0, @length-1].play()).bind @track_list
		for vol, idx in [0.15, 0.4]
			@track_list.push @scene.sound.add("ambient:#{idx+1}",{volume: vol, delay: 3000}).on 'complete', random
		random()
		# Additional preparations.
		@scene.input.setPollAlways true
		document.getElementById('ui').style.visibility = 'visible'
		# Finalization (welcome GUI).
		@welcome = @scene.add.container cfg.width / 2, cfg.height / 2, [
			@scene.add.text(0, 0, "Ammo:0", {fontFamily: 'Saira Stencil One', fontSize: 125, color: '#cb4154'})
				.setOrigin(0.5, 0.5).setShadow(0, 0, "crimson", 7, true, true)]
		for idx in [0..1]
			@welcome.add lbl = @scene.add.text 0, [1,-1][idx]*(cfg.height/2-60), "[click anywhere]".repeat(15), font =
				fontFamily: 'Titillium Web', fontSize: 35, color: 'coral'
			lbl.setAlpha(0.9).setOrigin(0.5, 0.5).setShadow(0, 0, "lightsalmon", 7, true, true)				
			@scene.tweens.add
				targets: lbl, x: [-300, 300][idx], yoyo: true, repeat: -1, duration: 5000, ease: 'Sine.easeInOut'
		@space.setInteractive().once 'pointerdown', (() ->
			@scene.cameras.main.fadeOut(1000); @scene.player = {alive: false}).bind @

	init: () ->
		# Init setup.
		obj.destroy() for obj in @scene.children.list[0..] when obj.type is 'Container'
		snd.destroy() for snd in @scene.sound.sounds when snd not in @track_list
		@scene.objects	= []
		@scene.enemies	= 0
		@scene.objects.push @scene.player = new Player @scene, @app.config
		# World setup.
		[width, height] = [2500, 2500]
		[x, y]			= [-width / 2, -height / 2]
		@scene.physics.world.setBounds	x, y, width, height
		@scene.cameras.main.setBounds	x, y, width, height
		# Legacy enemy.
		@spawn @scene.player.model.x + 200 * [1, -1][@rnd 0, 1], @scene.player.model.y + 200 * [1, -1][@rnd 0, 1]
		# Briefing.
		lines = [
			"That guiding systems looks pretty cheap", "It's a little tough to find ammo here"
			"Pacifism is a form of violence", "Rockets, rockets, rockets", "That run will never end"
			"Just another bad dream", "Thy shalt not kill"
		]
		@briefing?.destroy()
		@briefing = @scene.add.text @scene.player.model.x, start_y = @scene.player.model.y - 30,
			"...#{lines[@rnd 0, lines.length-1]}...", 
				{fontFamily: 'Saira Stencil One', fontSize: 20, color: 'Cyan'}
		@briefing.setOrigin(0.5, 0.5).setShadow(0, 0, "lightcoral", 7, true, true)
		@scene.tweens.add cfg =
			targets: @briefing, alpha: 0, duration: 1300, y: start_y + 40, ease: 'Sine.easeInOut'
		# Finalization.
		@spawnlag		= 0
		@welcome?.destroy()
		@space.rotation = 0
		@scene.cameras.main.fadeIn(1000)

	spawn: (x, y) ->
		{width, height} = @scene.physics.world.bounds		
		x = @scene.player.model.x + @rnd(@app.config.width / 2, width - @app.config.width)	 unless x?
		y = @scene.player.model.y + @rnd(@app.config.height / 2, height - @app.config.height) unless y?
		@scene.objects.push @enemy = new MissileBase @scene, x, y
		@spawnlag += Math.max 0, 800 - @scene.player.trashed * 50

	update: () ->
		[@space.tilePositionX, @space.tilePositionY] = [@scene.cameras.main.scrollX, @scene.cameras.main.scrollY]
		if @scene.cameras.main.fadeEffect.isRunning then return
		else return @space.rotation -= 0.001 unless @scene.player?
		if @scene.player.alive
			@scene.pending = []
			if @scene.enemies < 5 and (@spawnlag = Math.max 0, @spawnlag-1) is 0 then @spawn()
			@scene.objects = @scene.objects.filter (obj) -> obj.alive and obj.update()
			@scene.objects = @scene.objects.concat @scene.pending
		else @init(0)
			
# ==Main code==
new Game()