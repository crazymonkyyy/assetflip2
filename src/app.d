module app;

import raylib;
import core.stdc.stdio;
import core.math;
import core.time;
import std.random;
import std.array;
import std.math : sqrt, cos, sin, PI;
import core.stdc.string;
import collision;

// ============================================================================
// Constants
// ============================================================================
enum SCREEN_WIDTH = 1280;
enum SCREEN_HEIGHT = 720;
enum GRAVITY = 20.0f;
enum PLAYER_SPEED = 5.0f;
enum JUMP_STRENGTH = 8.0f;
enum MOUSE_SENSITIVITY = 0.002f;
enum PLAYER_HEIGHT = 1.0f;
enum PLAYER_RADIUS = 0.3f;

// Asset paths
enum ASSET_PATH = "../assetflip/";
enum MODEL_PATH = ASSET_PATH ~ "models/";
enum SOUND_PATH = ASSET_PATH ~ "sounds/";
enum SPRITE_PATH = ASSET_PATH ~ "sprites/";
enum SHADER_PATH = "shaders/";

// Colors
enum Color MAROON = Color(128, 0, 0, 255);
enum Color DARKGREEN = Color(0, 118, 0, 255);
enum Color BROWN = Color(162, 98, 44, 255);
enum Color GRAY = Color(128, 128, 128, 255);
enum Color DARKGRAY = Color(80, 80, 80, 255);
enum Color GREEN = Color(0, 228, 48, 255);
enum Color YELLOW = Color(253, 249, 0, 255);
enum Color BLACK = Color(0, 0, 0, 255);
enum Color WHITE = Color(255, 255, 255, 255);
enum Color LIGHTGRAY = Color(200, 200, 200, 255);
enum Color RAYWHITE = Color(245, 245, 245, 255);
enum Color DARKPURPLE = Color(112, 31, 126, 255);
enum Color DARKBLUE = Color(0, 82, 172, 255);
enum Color BEIGE = Color(200, 180, 120, 255);

// Key codes
enum KEY_W = 87;
enum KEY_S = 83;
enum KEY_A = 65;
enum KEY_D = 68;
enum KEY_SPACE = 32;
enum KEY_E = 69;
enum KEY_ESCAPE = 256;

// Mouse buttons
enum MOUSE_BUTTON_LEFT = 0;

// Camera projection
enum CAMERA_PERSPECTIVE = 0;

// ============================================================================
// Vector3 Helper Functions
// ============================================================================
Vector3 Vector3Zero() {
    return Vector3(0, 0, 0);
}

Vector3 Vector3Up() {
    return Vector3(0, 1, 0);
}

Vector3 Vector3Forward() {
    return Vector3(0, 0, -1);
}

float Vector3Length(Vector3 v) {
    return sqrt(v.x * v.x + v.y * v.y + v.z * v.z);
}

Vector3 Vector3Normalize(Vector3 v) {
    float len = Vector3Length(v);
    if (len > 0.0001f) {
        return Vector3(v.x / len, v.y / len, v.z / len);
    }
    return v;
}

Vector2 Vector2Normalize(Vector2 v) {
    float len = sqrt(v.x * v.x + v.y * v.y);
    if (len > 0.0001f) {
        return Vector2(v.x / len, v.y / len);
    }
    return v;
}

Vector3 Vector3Cross(Vector3 a, Vector3 b) {
    return Vector3(
        a.y * b.z - a.z * b.y,
        a.z * b.x - a.x * b.z,
        a.x * b.y - a.y * b.x
    );
}

Vector3 Vector3Lerp(Vector3 a, Vector3 b, float t) {
    return Vector3(
        a.x + (b.x - a.x) * t,
        a.y + (b.y - a.y) * t,
        a.z + (b.z - a.z) * t
    );
}

Vector3 Vector3Scale(Vector3 v, float scale) {
    return Vector3(v.x * scale, v.y * scale, v.z * scale);
}

Vector3 Vector3Add(Vector3 a, Vector3 b) {
    return Vector3(a.x + b.x, a.y + b.y, a.z + b.z);
}

Vector3 Vector3Subtract(Vector3 a, Vector3 b) {
    return Vector3(a.x - b.x, a.y - b.y, a.z - b.z);
}

float clamp(float value, float minVal, float maxVal) {
    if (value < minVal) return minVal;
    if (value > maxVal) return maxVal;
    return value;
}

// ============================================================================
// Audio Manager
// ============================================================================
class AudioManager {
    Sound[] sounds;
    string[] soundNames;
    
    this() {
        InitAudioDevice();
        sounds = [];
        soundNames = [];
    }
    
    ~this() {
        foreach (sound; sounds) {
            UnloadSound(sound);
        }
        CloseAudioDevice();
    }
    
    void loadSound(string name, string path) {
        Sound sound = LoadSound(path.ptr);
        sounds ~= sound;
        soundNames ~= name;
    }
    
    Sound getSound(string name) {
        for (size_t i = 0; i < soundNames.length; i++) {
            if (soundNames[i] == name) {
                return sounds[i];
            }
        }
        return Sound.init;
    }
    
    void play(string name) {
        Sound sound = getSound(name);
        if (sound.stream.buffer !is null) {
            PlaySound(sound);
        }
    }
}

// Global audio manager
AudioManager audio;

// ============================================================================
// Weapon Resource
// ============================================================================
class Weapon {
    string name;
    Model model;
    Vector3 modelPosition;
    Vector3 modelRotation;
    Vector3 muzzlePosition;
    float cooldown;
    float maxDistance;
    float damage;
    float spread;
    int shotCount;
    float knockback;
    Vector2 minKnockback;
    Vector2 maxKnockback;
    string soundShoot;
    Color color;
    Texture2D crosshair;
    
    float cooldownTimer;
    
    this(string name, Model mdl, Vector3 pos, Vector3 rot, Vector3 muzzle,
         float cooldown, float maxDist, float dmg, float spread,
         int shots, float kb, Vector2 minKb, Vector2 maxKb, 
         string sound, Color col, Texture2D cross) {
        this.name = name;
        this.model = mdl;
        this.modelPosition = pos;
        this.modelRotation = rot;
        this.muzzlePosition = muzzle;
        this.cooldown = cooldown;
        this.maxDistance = maxDist;
        this.damage = dmg;
        this.spread = spread;
        this.shotCount = shots;
        this.knockback = kb;
        this.minKnockback = minKb;
        this.maxKnockback = maxKb;
        this.soundShoot = sound;
        this.color = col;
        this.crosshair = cross;
        this.cooldownTimer = 0;
    }
    
    ~this() {
        if (model.meshes !is null) {
            UnloadModel(model);
        }
        if (crosshair.id != 0) {
            UnloadTexture(crosshair);
        }
    }
    
    bool isReady() {
        return cooldownTimer <= 0;
    }
    
    void update(float dt) {
        if (cooldownTimer > 0) {
            cooldownTimer -= dt;
        }
    }
    
    void fire() {
        cooldownTimer = cooldown;
    }
}

// ============================================================================
// Enemy Class
// ============================================================================
class Enemy {
    Vector3 position;
    Vector3 targetPosition;
    float health;
    float time;
    float shootTimer;
    bool destroyed;
    Model model;
    float size;
    float animationFrame;
    
    this(Vector3 pos, Model mdl, float hp = 100) {
        position = pos;
        targetPosition = pos;
        health = hp;
        time = 0;
        shootTimer = 0.25f;
        destroyed = false;
        model = mdl;
        size = 0.75f;
        animationFrame = 0;
    }
    
    ~this() {
        // Model is owned by asset manager, don't unload here
    }
    
    void update(float dt, Vector3 playerPos) {
        if (destroyed) return;
        
        time += dt;
        targetPosition.y += (cos(time * 5) * 1) * dt;
        position = targetPosition;
        
        shootTimer -= dt;
        if (shootTimer <= 0) {
            shootTimer = 0.25f;
        }
        
        animationFrame += dt * 8;
    }
    
    void damage(float amount) {
        health -= amount;
        if (health <= 0 && !destroyed) {
            destroy();
        }
    }
    
    void destroy() {
        destroyed = true;
        audio.play("enemy_destroy");
    }
    
    void draw() {
        if (destroyed) return;
        
        if (model.meshes !is null) {
            DrawModel(model, position, 1.0f, WHITE);
        } else {
            DrawSphere(position, size, MAROON);
            DrawSphereWires(position, size, 8, 8, DARKGRAY);
        }
    }
}

// ============================================================================
// Player Class
// ============================================================================
class Player {
    Vector3 position;
    Vector3 velocity;
    Vector3 movementVelocity;
    float rotationX;
    float rotationY;
    float gravity;
    int health;
    int jumpsRemaining;
    int numberOfJumps;
    bool onFloor;
    bool previouslyFloored;

    Camera3D camera;
    Weapon[] weapons;
    int weaponIndex;
    Weapon currentWeapon;

    float weaponRecoilZ;
    float containerOffsetZ;
    float weaponSwayTime;
    
    CollisionController collisionController;

    this() {
        position = Vector3(0, 0.5f, 0);
        velocity = Vector3Zero();
        movementVelocity = Vector3Zero();
        rotationX = 0;
        rotationY = 0;
        gravity = 0;
        health = 100;
        jumpsRemaining = 2;
        numberOfJumps = 2;
        onFloor = false;
        previouslyFloored = false;
        weaponRecoilZ = 0;
        containerOffsetZ = -0.5f;
        weaponSwayTime = 0;

        // Initialize collision controller (capsule: radius 0.3, height 1.0)
        collisionController = new CollisionController(position, 0.3f, 1.0f);

        camera.fovy = 80.0f;
        camera.up = Vector3Up();
        camera.position = position;
        camera.target = Vector3Add(position, Vector3(0, 1, 0));
        camera.projection = CAMERA_PERSPECTIVE;

        weapons = [];
        weaponIndex = 0;
    }

    void addWeapon(Weapon weapon) {
        weapons ~= weapon;
        if (weapons.length == 1) {
            currentWeapon = weapons[0];
        }
    }
    
    void addCollider(Model model, Matrix transform) {
        collisionController.addCollider(model, transform);
    }

    void update(float dt) {
        foreach (weapon; weapons) {
            weapon.update(dt);
        }

        gravity += GRAVITY * dt;

        handleInput(dt);

        // Calculate desired velocity
        Vector3 appliedVelocity = Vector3Lerp(velocity, movementVelocity, dt * 10);
        appliedVelocity.y = -gravity;
        velocity = appliedVelocity;

        // Update collision controller position
        collisionController.position = position;
        collisionController.velocity = appliedVelocity;
        
        // Update with collision detection
        collisionController.update(dt);
        
        // Get new position from collision controller
        Vector3 newPos = collisionController.position;
        
        // Check if grounded
        bool wasGrounded = onFloor;
        onFloor = collisionController.isGrounded() || newPos.y <= 0.5f;
        
        if (onFloor) {
            if (newPos.y <= 0.5f) {
                newPos.y = 0.5f;
            }
            if (gravity > 1 && !previouslyFloored) {
                audio.play("land");
            }
            jumpsRemaining = numberOfJumps;
            gravity = 0;
        } else {
            onFloor = false;
        }
        
        position = newPos;
        previouslyFloored = onFloor;

        camera.position = position;
        Vector3 lookTarget = Vector3Add(position, Vector3(
            sin(rotationY) * cos(rotationX),
            sin(rotationX),
            cos(rotationY) * cos(rotationX)
        ));
        camera.target = lookTarget;

        weaponSwayTime += dt;
        float swayAmount = Vector3Length(appliedVelocity) / PLAYER_SPEED * 0.03f;
        weaponRecoilZ = containerOffsetZ + swayAmount * sin(weaponSwayTime * 10);
    }
    
    void handleInput(float dt) {
        float moveX = 0;
        float moveY = 0;
        
        if (IsKeyDown(KEY_W)) moveY = -1;
        if (IsKeyDown(KEY_S)) moveY = 1;
        if (IsKeyDown(KEY_A)) moveX = -1;
        if (IsKeyDown(KEY_D)) moveX = 1;
        
        Vector2 input = Vector2(moveX, moveY);
        if (input.x != 0 || input.y != 0) {
            input = Vector2Normalize(input);
        }
        
        float cosY = cos(rotationY);
        float sinY = sin(rotationY);
        
        movementVelocity.x = (input.x * cosY - input.y * sinY) * PLAYER_SPEED;
        movementVelocity.z = (input.x * sinY + input.y * cosY) * PLAYER_SPEED;
        
        // Always capture mouse when window is focused
        if (!IsCursorHidden()) {
            HideCursor();
            DisableCursor();
        }
        
        Vector2 mouseDelta = GetMouseDelta();
        rotationY -= mouseDelta.x * MOUSE_SENSITIVITY;
        rotationX -= mouseDelta.y * MOUSE_SENSITIVITY;
        rotationX = clamp(rotationX, -PI / 2 + 0.1f, PI / 2 - 0.1f);
        
        if (IsKeyPressed(KEY_SPACE)) {
            if (jumpsRemaining > 0) {
                jump();
            }
        }
        
        if (IsMouseButtonDown(MOUSE_BUTTON_LEFT)) {
            shoot();
        }
        
        if (IsKeyPressed(KEY_E)) {
            switchWeapon();
        }
        
        if (IsKeyPressed(KEY_ESCAPE)) {
            // Show cursor and enable it when escape is pressed
            ShowCursor();
            EnableCursor();
        }
    }
    
    void jump() {
        audio.play("jump_a");
        gravity = -JUMP_STRENGTH;
        jumpsRemaining--;
    }
    
    void shoot() {
        if (!currentWeapon.isReady()) return;
        
        currentWeapon.fire();
        audio.play(currentWeapon.soundShoot);
        
        weaponRecoilZ += 0.15f;
        rotationX += GetRandomValue(1, 3) * 0.001f;
        rotationY += GetRandomValue(-3, 3) * 0.001f;
        movementVelocity.z += currentWeapon.knockback * 0.1f;
    }
    
    void switchWeapon() {
        weaponIndex = cast(int)((weaponIndex + 1) % weapons.length);
        currentWeapon = weapons[weaponIndex];
        audio.play("weapon_change");
    }
    
    void damage(float amount) {
        health -= cast(int)amount;
        if (health < 0) {
            health = 100;
            position = Vector3(0, 0.5f, 0);
            velocity = Vector3Zero();
        }
    }
    
    void draw() {
        drawWeapon();
    }
    
    void drawWeapon() {
        if (currentWeapon.model.meshes is null) return;
        
        // Calculate weapon position relative to camera
        Vector3 right = Vector3Normalize(Vector3Cross(camera.up, 
            Vector3Subtract(camera.target, camera.position)));
        Vector3 up = Vector3Normalize(Vector3Cross(
            Vector3Subtract(camera.target, camera.position), right));
        
        Vector3 weaponPos = Vector3Add(camera.position, 
            Vector3Add(Vector3Scale(right, currentWeapon.modelPosition.x),
            Vector3Add(Vector3Scale(up, currentWeapon.modelPosition.y),
            Vector3Scale(Vector3Normalize(Vector3Subtract(camera.target, camera.position)), 
                        -currentWeapon.modelPosition.z))));
        
        weaponPos.y += weaponRecoilZ;
        
        // Draw weapon model
        Matrix weaponRot = MatrixRotateXYZ(Vector3(
            currentWeapon.modelRotation.x * PI / 180,
            currentWeapon.modelRotation.y * PI / 180,
            currentWeapon.modelRotation.z * PI / 180
        ));
        
        DrawModelEx(currentWeapon.model, weaponPos, Vector3(0, 1, 0), 0, 
            Vector3(0.5f, 0.5f, 0.5f), WHITE);
    }
}

// ============================================================================
// Level / Platform
// ============================================================================
struct Platform {
    Vector3 position;
    Vector3 size;
    Model model;
    bool useModel;
    Color color;
    
    this(Vector3 pos, Vector3 sz, Color col) {
        position = pos;
        size = sz;
        model = Model.init;
        useModel = false;
        color = col;
    }
    
    this(Vector3 pos, Model mdl) {
        position = pos;
        size = Vector3(1, 1, 1);
        model = mdl;
        useModel = true;
        color = WHITE;
    }
    
    void draw() {
        if (useModel && model.meshes !is null) {
            DrawModel(model, position, 1.0f, WHITE);
        } else {
            DrawCube(position, size.x, size.y, size.z, color);
            DrawCubeWires(position, size.x, size.y, size.z, DARKGRAY);
        }
    }
}

// ============================================================================
// Decoration (trees, rocks, props)
// ============================================================================
struct Decoration {
    Vector3 position;
    Model model;
    float scale;
    float rotationY;
    
    this(Vector3 pos, Model mdl, float scl = 1.0f, float rot = 0) {
        position = pos;
        model = mdl;
        scale = scl;
        rotationY = rot;
    }
    
    void draw() {
        if (model.meshes !is null) {
            DrawModelEx(model, position, Vector3(0, 1, 0), rotationY, 
                Vector3(scale, scale, scale), WHITE);
        }
    }
}

// ============================================================================
// Asset Manager
// ============================================================================
class AssetManager {
    Model[] models;
    string[] modelNames;
    Texture2D[] textures;
    string[] textureNames;
    Shader moodyShader;
    Shader postShader;
    RenderTexture2D renderTarget;
    float time;

    this() {
        models = [];
        modelNames = [];
        textures = [];
        textureNames = [];
        moodyShader = Shader.init;
        postShader = Shader.init;
        time = 0;
    }

    ~this() {
        foreach (model; models) {
            if (model.meshes !is null) {
                UnloadModel(model);
            }
        }
        foreach (texture; textures) {
            if (texture.id != 0) {
                UnloadTexture(texture);
            }
        }
        if (moodyShader.id != 0) {
            UnloadShader(moodyShader);
        }
        if (postShader.id != 0) {
            UnloadShader(postShader);
        }
        if (renderTarget.id != 0) {
            UnloadRenderTexture(renderTarget);
        }
    }

    void loadShaders() {
        // Load moody shader
        moodyShader = LoadShader(
            (SHADER_PATH ~ "moody.vert").ptr,
            (SHADER_PATH ~ "moody.frag").ptr
        );
        
        // Load post-processing shader
        postShader = LoadShader(
            null,
            (SHADER_PATH ~ "moody_post.frag").ptr
        );
        
        // Create render target for post-processing
        renderTarget = LoadRenderTexture(SCREEN_WIDTH, SCREEN_HEIGHT);
    }

    Model loadModel(string name, string path) {
        Model model = LoadModel(path.ptr);
        
        // Apply moody shader to all materials
        if (moodyShader.id != 0) {
            for (int i = 0; i < model.materialCount; i++) {
                model.materials[i].shader = moodyShader;
            }
        }
        
        models ~= model;
        modelNames ~= name;
        return model;
    }

    Model getModel(string name) {
        for (size_t i = 0; i < modelNames.length; i++) {
            if (modelNames[i] == name) {
                return models[i];
            }
        }
        return Model.init;
    }

    Texture2D loadTexture(string name, string path) {
        Texture2D texture = LoadTexture(path.ptr);
        textures ~= texture;
        textureNames ~= name;
        return texture;
    }

    Texture2D getTexture(string name) {
        for (size_t i = 0; i < textureNames.length; i++) {
            if (textureNames[i] == name) {
                return textures[i];
            }
        }
        return Texture2D.init;
    }
    
    void updateShaderUniforms(Vector3 viewPos) {
        time += 0.016f;
        
        if (moodyShader.id != 0) {
            SetShaderValue(moodyShader, GetShaderLocation(moodyShader, "viewPos"), &viewPos, ShaderUniformDataType.SHADER_UNIFORM_VEC3);
            SetShaderValue(moodyShader, GetShaderLocation(moodyShader, "time"), &time, ShaderUniformDataType.SHADER_UNIFORM_FLOAT);
            Vector2 screenSize = Vector2(SCREEN_WIDTH, SCREEN_HEIGHT);
            SetShaderValue(moodyShader, GetShaderLocation(moodyShader, "screenSize"), 
                &screenSize, ShaderUniformDataType.SHADER_UNIFORM_VEC2);
        }
        
        if (postShader.id != 0) {
            SetShaderValue(postShader, GetShaderLocation(postShader, "time"), &time, ShaderUniformDataType.SHADER_UNIFORM_FLOAT);
            Vector2 screenSize = Vector2(SCREEN_WIDTH, SCREEN_HEIGHT);
            SetShaderValue(postShader, GetShaderLocation(postShader, "screenSize"), 
                &screenSize, ShaderUniformDataType.SHADER_UNIFORM_VEC2);
        }
    }
}

// ============================================================================
// Game Class
// ============================================================================
class Game {
    Player player;
    Enemy[] enemies;
    Platform[] platforms;
    Decoration[] decorations;
    AssetManager assets;
    int score;
    bool paused;
    Texture2D skybox;
    
    this() {
        assets = new AssetManager();
        player = new Player();
        enemies = [];
        platforms = [];
        decorations = [];
        score = 0;
        paused = false;

        loadAssets();
        createLevel();
    }
    
    ~this() {
        // GC will handle cleanup
    }
    
    void loadAssets() {
        // Load shaders first
        assets.loadShaders();
        
        // Load weapon models
        Model blasterModel = assets.loadModel("blaster", MODEL_PATH ~ "blaster.glb");
        Model repeaterModel = assets.loadModel("blaster-repeater", MODEL_PATH ~ "blaster-repeater.glb");

        // Load enemy model
        Model enemyModel = assets.loadModel("enemy", MODEL_PATH ~ "enemy-flying.glb");

        // Load platform models
        Model platformModel = assets.loadModel("platform", MODEL_PATH ~ "platform.glb");
        Model wallLowModel = assets.loadModel("wall-low", MODEL_PATH ~ "wall-low.glb");
        Model wallHighModel = assets.loadModel("wall-high", MODEL_PATH ~ "wall-high.glb");

        // Load crosshair textures
        Texture2D blasterCrosshair = assets.loadTexture("crosshair", SPRITE_PATH ~ "crosshair.png");
        Texture2D repeaterCrosshair = assets.loadTexture("crosshair-repeater", SPRITE_PATH ~ "crosshair-repeater.png");

        // Load skybox
        skybox = LoadTexture((SPRITE_PATH ~ "skybox.png").ptr);

        // Create weapons with models
        player.addWeapon(new Weapon("Blaster", blasterModel,
            Vector3(0.3f, -0.25f, -0.5f), Vector3(0, 180, 0), Vector3(0.3f, -0.2f, -0.8f),
            0.15f, 50.0f, 25.0f, 0.5f, 1, 20.0f,
            Vector2(0.001f, 0.001f), Vector2(0.0025f, 0.002f),
            "blaster", GREEN, blasterCrosshair));

        player.addWeapon(new Weapon("Repeater", repeaterModel,
            Vector3(0.3f, -0.25f, -0.5f), Vector3(0, 180, 0), Vector3(0.3f, -0.2f, -0.8f),
            0.1f, 40.0f, 15.0f, 1.0f, 3, 15.0f,
            Vector2(0.001f, 0.001f), Vector2(0.002f, 0.0015f),
            "blaster_repeater", YELLOW, repeaterCrosshair));
    }
    
    void createLevel() {
        // Load decorative models
        Model grassModel = assets.loadModel("grass", MODEL_PATH ~ "grass.glb");
        Model grassSmallModel = assets.loadModel("grass-small", MODEL_PATH ~ "grass-small.glb");
        Model crateModel = assets.loadModel("crate", MODEL_PATH ~ "crate-small.glb");
        Model cloudModel = assets.loadModel("cloud", MODEL_PATH ~ "cloud.glb");
        Model stairsModel = assets.loadModel("stairs", "models/stairs.glb");

        // Ground platform
        platforms ~= Platform(Vector3(0, -0.5f, 0), Vector3(20, 1, 20), DARKGREEN);

        // Various platforms
        platforms ~= Platform(Vector3(-5, 1, 5), Vector3(4, 0.5f, 4), BROWN);
        platforms ~= Platform(Vector3(5, 2, -5), Vector3(4, 0.5f, 4), BROWN);
        platforms ~= Platform(Vector3(-8, 3, -8), Vector3(4, 0.5f, 4), BROWN);
        platforms ~= Platform(Vector3(8, 1.5f, 8), Vector3(4, 0.5f, 4), BROWN);

        // Walls
        platforms ~= Platform(Vector3(-10, 1, 0), Vector3(1, 2, 10), GRAY);
        platforms ~= Platform(Vector3(10, 1, 0), Vector3(1, 2, 10), GRAY);
        platforms ~= Platform(Vector3(0, 1, -10), Vector3(20, 2, 1), GRAY);

        // Add staircase using GLB model (leads up to platform at -5, 1, 5)
        decorations ~= Decoration(Vector3(-7, 0, 3), stairsModel, 1.0f, -PI/4);
        platforms ~= Platform(Vector3(-7, 0, 3), stairsModel);

        // Add decorations (grass, crates as rocks, clouds as trees/bushes)
        // Grass patches
        for (int i = 0; i < 30; i++) {
            float x = (GetRandomValue(0, 100) / 10.0f) - 5.0f;
            float z = (GetRandomValue(0, 100) / 10.0f) - 5.0f;
            float rot = GetRandomValue(0, 360) * PI / 180;
            float scale = 0.5f + GetRandomValue(0, 50) / 100.0f;
            
            // Don't place on spawn area or stairs
            if (Vector3Length(Vector3(x, 0, z)) > 2.0f && Vector3Length(Vector3(x + 7, 0, z - 3)) > 1.5f) {
                decorations ~= Decoration(Vector3(x, 0, z), grassModel, scale, rot);
            }
        }
        
        // Crates as "rocks"
        decorations ~= Decoration(Vector3(-3, 0.3f, 3), crateModel, 1.0f, PI / 4);
        decorations ~= Decoration(Vector3(4, 0.3f, -4), crateModel, 1.2f, PI / 6);
        decorations ~= Decoration(Vector3(-6, 0.3f, -2), crateModel, 0.8f, PI / 3);
        decorations ~= Decoration(Vector3(2, 2.3f, -3), crateModel, 1.0f, PI / 8);
        
        // Clouds as "trees/bushes" (scaled down)
        decorations ~= Decoration(Vector3(-7, 0.5f, 4), cloudModel, 0.4f, 0);
        decorations ~= Decoration(Vector3(6, 0.5f, 6), cloudModel, 0.5f, PI / 4);
        decorations ~= Decoration(Vector3(-4, 4.3f, 8), cloudModel, 0.35f, PI / 6);
        decorations ~= Decoration(Vector3(7, 0.5f, -7), cloudModel, 0.45f, PI / 3);
        
        // Add more grass on platforms
        decorations ~= Decoration(Vector3(-5, 1.3f, 5), grassSmallModel, 1.5f, PI / 4);
        decorations ~= Decoration(Vector3(5, 2.3f, -5), grassSmallModel, 1.5f, PI / 6);
        
        // Add enemies
        enemies ~= new Enemy(Vector3(-5, 3, 5), assets.getModel("enemy"));
        enemies ~= new Enemy(Vector3(5, 4, -5), assets.getModel("enemy"));
        enemies ~= new Enemy(Vector3(-8, 5, -8), assets.getModel("enemy"));
        enemies ~= new Enemy(Vector3(8, 3, 8), assets.getModel("enemy"));
        
        // Add colliders for player
        // Platforms (using simple boxes for collision)
        addPlatformCollider(Vector3(-5, 1, 5), Vector3(4, 0.5f, 4));
        addPlatformCollider(Vector3(5, 2, -5), Vector3(4, 0.5f, 4));
        addPlatformCollider(Vector3(-8, 3, -8), Vector3(4, 0.5f, 4));
        addPlatformCollider(Vector3(8, 1.5f, 8), Vector3(4, 0.5f, 4));
        
        // Walls
        addPlatformCollider(Vector3(-10, 1, 0), Vector3(1, 2, 10));
        addPlatformCollider(Vector3(10, 1, 0), Vector3(1, 2, 10));
        addPlatformCollider(Vector3(0, 1, -10), Vector3(20, 2, 1));
        
        // Stairs collider using mesh
        addStairsCollider(Vector3(-7, 0, 3), -PI/4);
        
        // Crates as collision objects
        addCrateCollider(Vector3(-3, 0.3f, 3));
        addCrateCollider(Vector3(4, 0.3f, -4));
        addCrateCollider(Vector3(-6, 0.3f, -2));
        addCrateCollider(Vector3(2, 2.3f, -3));
    }
    
    void addStairsCollider(Vector3 pos, float rotationY) {
        Model stairsModel = assets.getModel("stairs");
        if (stairsModel.meshes !is null) {
            Matrix transform = MatrixRotateY(rotationY);
            transform = MatrixMultiply(transform, MatrixTranslate(pos.x, pos.y, pos.z));
            player.addCollider(stairsModel, transform);
        }
    }
    
    void addPlatformCollider(Vector3 pos, Vector3 size) {
        // Create a simple box mesh for collision
        Mesh boxMesh = GenMeshCube(size.x, size.y, size.z);
        Model boxModel = LoadModelFromMesh(boxMesh);
        
        Matrix transform = MatrixTranslate(pos.x, pos.y, pos.z);
        player.addCollider(boxModel, transform);
    }
    
    void addCrateCollider(Vector3 pos) {
        Model crateModel = assets.getModel("crate");
        if (crateModel.meshes !is null) {
            Matrix transform = MatrixTranslate(pos.x, pos.y, pos.z);
            player.addCollider(crateModel, transform);
        }
    }
    
    void update(float dt) {
        if (IsCursorHidden()) {
            // Game is active
            if (paused) {
                paused = false;
            }
            
            player.update(dt);
            
            foreach (enemy; enemies) {
                enemy.update(dt, player.position);
            }
            
            foreach (enemy; enemies) {
                if (!enemy.destroyed) {
                    Vector3 diff = Vector3Subtract(player.position, enemy.position);
                    float dist = Vector3Length(diff);
                    if (dist < 1.0f) {
                        player.damage(0.5f);
                    }
                }
            }
            
            // Clean up destroyed enemies and spawn new ones
            Enemy[] aliveEnemies = [];
            foreach (enemy; enemies) {
                if (!enemy.destroyed) {
                    aliveEnemies ~= enemy;
                } else {
                    score += 100;
                }
            }
            enemies = aliveEnemies;
            
            if (enemies.length < 4 && GetRandomValue(0, 100) < 2) {
                float angle = GetRandomValue(0, 360) * PI / 180;
                float dist = 10 + GetRandomValue(0, 50) / 10.0f;
                enemies ~= new Enemy(Vector3(
                    player.position.x + cos(angle) * dist,
                    3 + GetRandomValue(0, 50) / 10.0f,
                    player.position.z + sin(angle) * dist
                ), assets.getModel("enemy"));
            }
        } else {
            // Cursor is visible, game is paused
            paused = true;
        }
    }
    
    void draw() {
        // Update shader uniforms
        assets.updateShaderUniforms(player.camera.position);

        // Render to texture for post-processing
        BeginTextureMode(assets.renderTarget);
        ClearBackground(Color(10, 10, 20, 255));

        BeginMode3D(player.camera);

        // Dark foggy background
        DrawSphere(player.position, 50.0f, Color(30, 30, 50, 255));

        foreach (platform; platforms) {
            platform.draw();
        }

        foreach (decoration; decorations) {
            decoration.draw();
        }

        foreach (enemy; enemies) {
            enemy.draw();
        }

        player.draw();

        EndMode3D();
        
        // Draw HUD to render texture too
        drawHUD();
        
        EndTextureMode();
        
        // Apply post-processing shader and draw to screen
        BeginDrawing();
        ClearBackground(BLACK);
        
        // Draw the rendered texture with post-processing shader
        BeginShaderMode(assets.postShader);
        DrawTextureRec(
            assets.renderTarget.texture,
            Rectangle(0, 0, SCREEN_WIDTH, -SCREEN_HEIGHT),
            Vector2(0, 0),
            WHITE
        );
        EndShaderMode();
        
        if (paused) {
            DrawRectangle(0, 0, SCREEN_WIDTH, SCREEN_HEIGHT, Color(0, 0, 0, 180));
            DrawText("PAUSED", SCREEN_WIDTH/2 - 80, SCREEN_HEIGHT/2 - 30, 40, WHITE);
            DrawText("Click to resume", SCREEN_WIDTH/2 - 100, SCREEN_HEIGHT/2 + 20, 20, LIGHTGRAY);
        }
        
        EndDrawing();
    }
    
    void drawHUD() {
        // Health
        DrawText(TextFormat("HEALTH: %d%%", player.health), 20, SCREEN_HEIGHT - 60, 30, DARKGREEN);
        
        // Weapon name
        DrawText(TextFormat("WEAPON: %s", player.currentWeapon.name.ptr), 20, SCREEN_HEIGHT - 100, 25, DARKBLUE);
        
        // Score
        DrawText(TextFormat("SCORE: %d", score), SCREEN_WIDTH - 200, 20, 30, DARKPURPLE);
        
        // Crosshair
        int cx = SCREEN_WIDTH / 2;
        int cy = SCREEN_HEIGHT / 2;
        if (player.currentWeapon.crosshair.id != 0) {
            DrawTexture(player.currentWeapon.crosshair, cx - 16, cy - 16, WHITE);
        } else {
            DrawLine(cx - 10, cy, cx + 10, cy, BLACK);
            DrawLine(cx, cy - 10, cx, cy + 10, BLACK);
        }

        // Weapon cooldown indicator
        float cooldownPercent = player.currentWeapon.cooldownTimer / player.currentWeapon.cooldown;
        DrawRectangle(cx - 50, cy + 30, 100, 5, GRAY);
        DrawRectangle(cx - 50, cy + 30, cast(int)(100 * (1 - cooldownPercent)), 5, GREEN);
    }
}

// ============================================================================
// Main Entry Point
// ============================================================================
int main() {
    InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "AssetFlip2 - D Language FPS");
    SetTargetFPS(60);
    
    // Initialize audio
    audio = new AudioManager();
    
    // Load sounds
    audio.loadSound("blaster", SOUND_PATH ~ "blaster.ogg");
    audio.loadSound("blaster_repeater", SOUND_PATH ~ "blaster_repeater.ogg");
    audio.loadSound("jump_a", SOUND_PATH ~ "jump_a.ogg");
    audio.loadSound("land", SOUND_PATH ~ "land.ogg");
    audio.loadSound("weapon_change", SOUND_PATH ~ "weapon_change.ogg");
    audio.loadSound("enemy_destroy", SOUND_PATH ~ "enemy_destroy.ogg");
    
    // Capture mouse
    HideCursor();
    DisableCursor();
    
    Game game = new Game();
    
    float deltaTime = 0;
    
    while (!WindowShouldClose()) {
        deltaTime = GetFrameTime();
        
        // Check if we should re-capture mouse
        if (IsKeyPressed(KEY_ESCAPE)) {
            if (IsCursorHidden()) {
                ShowCursor();
                EnableCursor();
            } else {
                HideCursor();
                DisableCursor();
            }
        }
        
        // Re-capture mouse if left click and cursor is visible
        if (IsMouseButtonPressed(MOUSE_BUTTON_LEFT) && !IsCursorHidden()) {
            HideCursor();
            DisableCursor();
        }
        
        game.update(deltaTime);
        game.draw();
    }

    // GC will handle cleanup
    CloseWindow();

    return 0;
}
