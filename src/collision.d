module collision;

import raylib;
import core.stdc.stdio;
import core.math;
import std.math : sqrt, cos, sin, PI, fabs;

// ============================================================================
// Capsule Collision System
// ============================================================================

struct Capsule {
    Vector3 start;      // Bottom point of capsule
    Vector3 end;        // Top point of capsule
    float radius;
    
    Vector3 center() {
        return Vector3(
            (start.x + end.x) * 0.5f,
            (start.y + end.y) * 0.5f,
            (start.z + end.z) * 0.5f
        );
    }
    
    float height() {
        return Vector3Length(Vector3Subtract(end, start));
    }
}

struct CollisionResult {
    bool collided;
    Vector3 normal;
    float penetration;
    Vector3 contactPoint;
    
    static CollisionResult none() {
        CollisionResult result;
        result.collided = false;
        result.normal = Vector3(0, 0, 0);
        result.penetration = 0;
        result.contactPoint = Vector3(0, 0, 0);
        return result;
    }
}

// Triangle structure for mesh collision
struct Triangle {
    Vector3 v0, v1, v2;
    Vector3 normal;
    
    Vector3 centroid() {
        return Vector3(
            (v0.x + v1.x + v2.x) / 3.0f,
            (v0.y + v1.y + v2.y) / 3.0f,
            (v0.z + v1.z + v2.z) / 3.0f
        );
    }
}

// ============================================================================
// Vector Helper Functions
// ============================================================================

Vector3 vec3Zero() {
    return Vector3(0, 0, 0);
}

Vector3 vec3Up() {
    return Vector3(0, 1, 0);
}

float vec3Length(Vector3 v) {
    return sqrt(v.x * v.x + v.y * v.y + v.z * v.z);
}

Vector3 vec3Normalize(Vector3 v) {
    float len = vec3Length(v);
    if (len > 0.0001f) {
        return Vector3(v.x / len, v.y / len, v.z / len);
    }
    return v;
}

float vec3Dot(Vector3 a, Vector3 b) {
    return a.x * b.x + a.y * b.y + a.z * b.z;
}

Vector3 vec3Cross(Vector3 a, Vector3 b) {
    return Vector3(
        a.y * b.z - a.z * b.y,
        a.z * b.x - a.x * b.z,
        a.x * b.y - a.y * b.x
    );
}

Vector3 vec3Lerp(Vector3 a, Vector3 b, float t) {
    return Vector3(
        a.x + (b.x - a.x) * t,
        a.y + (b.y - a.y) * t,
        a.z + (b.z - a.z) * t
    );
}

Vector3 vec3Scale(Vector3 v, float s) {
    return Vector3(v.x * s, v.y * s, v.z * s);
}

Vector3 vec3Add(Vector3 a, Vector3 b) {
    return Vector3(a.x + b.x, a.y + b.y, a.z + b.z);
}

Vector3 vec3Subtract(Vector3 a, Vector3 b) {
    return Vector3(a.x - b.x, a.y - b.y, a.z - b.z);
}

// Get closest point on line segment to point
Vector3 closestPointOnSegment(Vector3 p, Vector3 a, Vector3 b) {
    Vector3 ab = vec3Subtract(b, a);
    Vector3 ap = vec3Subtract(p, a);
    
    float t = vec3Dot(ap, ab) / vec3Dot(ab, ab);
    t = clamp(t, 0.0f, 1.0f);
    
    return vec3Add(a, vec3Scale(ab, t));
}

float clamp(float value, float minVal, float maxVal) {
    if (value < minVal) return minVal;
    if (value > maxVal) return maxVal;
    return value;
}

// ============================================================================
// Triangle Helpers
// ============================================================================

Triangle createTriangle(Vector3 a, Vector3 b, Vector3 c) {
    Triangle tri;
    tri.v0 = a;
    tri.v1 = b;
    tri.v2 = c;
    
    Vector3 edge1 = vec3Subtract(b, a);
    Vector3 edge2 = vec3Subtract(c, a);
    tri.normal = vec3Normalize(vec3Cross(edge1, edge2));
    
    return tri;
}

// ============================================================================
// Sphere-Triangle Collision
// ============================================================================

CollisionResult sphereTriangleCollision(Vector3 sphereCenter, float radius, Triangle tri) {
    CollisionResult result = CollisionResult.none();
    
    // Find closest point on triangle to sphere center
    Vector3 closest = closestPointOnTriangle(sphereCenter, tri);
    
    // Check distance
    Vector3 diff = vec3Subtract(sphereCenter, closest);
    float distSq = vec3Dot(diff, diff);
    
    if (distSq < radius * radius) {
        result.collided = true;
        float dist = sqrt(distSq);
        
        if (dist > 0.0001f) {
            result.normal = vec3Scale(diff, 1.0f / dist);
            result.penetration = radius - dist;
        } else {
            result.normal = tri.normal;
            result.penetration = radius;
        }
        
        result.contactPoint = closest;
    }
    
    return result;
}

// Find closest point on triangle to a point
Vector3 closestPointOnTriangle(Vector3 p, Triangle tri) {
    // Check if P is in vertex region outside A
    Vector3 ab = vec3Subtract(tri.v1, tri.v0);
    Vector3 ac = vec3Subtract(tri.v2, tri.v0);
    Vector3 ap = vec3Subtract(p, tri.v0);
    
    float d1 = vec3Dot(ab, ap);
    float d2 = vec3Dot(ac, ap);
    
    if (d1 <= 0.0f && d2 <= 0.0f) {
        return tri.v0; // Closest to vertex A
    }
    
    // Check if P is in vertex region outside B
    Vector3 bp = vec3Subtract(p, tri.v1);
    float d3 = vec3Dot(ab, bp);
    float d4 = vec3Dot(ac, bp);
    
    if (d3 >= 0.0f && d4 <= d3) {
        return tri.v1; // Closest to vertex B
    }
    
    // Check if P is in edge region of AB
    float vc = d1 * d4 - d3 * d2;
    if (vc <= 0.0f && d1 >= 0.0f && d3 <= 0.0f) {
        float v = d1 / (d1 - d3);
        return vec3Add(tri.v0, vec3Scale(ab, v)); // On edge AB
    }
    
    // Check if P is in vertex region outside C
    Vector3 cp = vec3Subtract(p, tri.v2);
    float d5 = vec3Dot(ab, cp);
    float d6 = vec3Dot(ac, cp);
    
    if (d6 >= 0.0f && d5 <= d6) {
        return tri.v2; // Closest to vertex C
    }
    
    // Check if P is in edge region of AC
    float vb = d5 * d2 - d1 * d6;
    if (vb <= 0.0f && d2 >= 0.0f && d6 <= 0.0f) {
        float w = d2 / (d2 - d6);
        return vec3Add(tri.v0, vec3Scale(ac, w)); // On edge AC
    }
    
    // Check if P is in edge region of BC
    float va = d3 * d6 - d5 * d4;
    if (va <= 0.0f && (d4 - d3) >= 0.0f && (d5 - d6) >= 0.0f) {
        float w = (d4 - d3) / ((d4 - d3) + (d5 - d6));
        return vec3Add(tri.v1, vec3Scale(vec3Subtract(tri.v2, tri.v1), w)); // On edge BC
    }
    
    // P is inside the triangle
    float denom = 1.0f / (va + vb + vc);
    float v = vb * denom;
    float w = vc * denom;
    
    return vec3Add(tri.v0, vec3Add(vec3Scale(ab, v), vec3Scale(ac, w)));
}

// ============================================================================
// Capsule-Triangle Collision
// ============================================================================

CollisionResult capsuleTriangleCollision(Capsule capsule, Triangle tri) {
    CollisionResult result = CollisionResult.none();
    
    // Test collision at multiple points along capsule
    int steps = 5;
    float stepSize = capsule.height() / steps;
    Vector3 capsuleDir = vec3Normalize(vec3Subtract(capsule.end, capsule.start));
    
    for (int i = 0; i <= steps; i++) {
        float t = cast(float)i / steps;
        Vector3 point = vec3Add(capsule.start, vec3Scale(capsuleDir, t * capsule.height()));
        
        CollisionResult sphereResult = sphereTriangleCollision(point, capsule.radius, tri);
        
        if (sphereResult.collided) {
            if (!result.collided || sphereResult.penetration > result.penetration) {
                result = sphereResult;
            }
        }
    }
    
    return result;
}

// ============================================================================
// Capsule-Mesh Collision
// ============================================================================

CollisionResult capsuleMeshCollision(Capsule capsule, Model model, Matrix transform) {
    CollisionResult result = CollisionResult.none();
    
    if (model.meshes is null || model.meshCount == 0) {
        return result;
    }
    
    // For each mesh
    for (int m = 0; m < model.meshCount; m++) {
        Mesh mesh = model.meshes[m];
        
        if (mesh.vertices is null) continue;
        
        // For each triangle in mesh
        int triangleCount = mesh.triangleCount;
        if (triangleCount == 0 && mesh.vertexCount >= 3) {
            triangleCount = mesh.vertexCount / 3;
        }
        
        for (int t = 0; t < triangleCount; t++) {
            Triangle tri;
            
            if (mesh.indices !is null) {
                // Indexed mesh
                ushort i0 = mesh.indices[t * 3];
                ushort i1 = mesh.indices[t * 3 + 1];
                ushort i2 = mesh.indices[t * 3 + 2];
                
                tri.v0 = Vector3Transform(Vector3(mesh.vertices[i0 * 3], mesh.vertices[i0 * 3 + 1], mesh.vertices[i0 * 3 + 2]), transform);
                tri.v1 = Vector3Transform(Vector3(mesh.vertices[i1 * 3], mesh.vertices[i1 * 3 + 1], mesh.vertices[i1 * 3 + 2]), transform);
                tri.v2 = Vector3Transform(Vector3(mesh.vertices[i2 * 3], mesh.vertices[i2 * 3 + 1], mesh.vertices[i2 * 3 + 2]), transform);
            } else {
                // Non-indexed mesh
                tri.v0 = Vector3Transform(Vector3(mesh.vertices[t * 9], mesh.vertices[t * 9 + 1], mesh.vertices[t * 9 + 2]), transform);
                tri.v1 = Vector3Transform(Vector3(mesh.vertices[t * 9 + 3], mesh.vertices[t * 9 + 4], mesh.vertices[t * 9 + 5]), transform);
                tri.v2 = Vector3Transform(Vector3(mesh.vertices[t * 9 + 6], mesh.vertices[t * 9 + 7], mesh.vertices[t * 9 + 8]), transform);
            }
            
            Vector3 edge1 = vec3Subtract(tri.v1, tri.v0);
            Vector3 edge2 = vec3Subtract(tri.v2, tri.v0);
            tri.normal = vec3Normalize(vec3Cross(edge1, edge2));
            
            // Test collision
            CollisionResult triResult = capsuleTriangleCollision(capsule, tri);
            
            if (triResult.collided) {
                if (!result.collided || triResult.penetration > result.penetration) {
                    result = triResult;
                }
            }
        }
    }
    
    return result;
}

// ============================================================================
// Simple Bounding Box Collision (for optimization)
// ============================================================================

struct BoundingBox {
    Vector3 min;
    Vector3 max;
    
    bool overlaps(Capsule capsule) {
        // Find closest point on AABB to capsule start
        Vector3 closestStart = Vector3(
            clamp(capsule.start.x, min.x, max.x),
            clamp(capsule.start.y, min.y, max.y),
            clamp(capsule.start.z, min.z, max.z)
        );
        
        // Find closest point on AABB to capsule end
        Vector3 closestEnd = Vector3(
            clamp(capsule.end.x, min.x, max.x),
            clamp(capsule.end.y, min.y, max.y),
            clamp(capsule.end.z, min.z, max.z)
        );
        
        // Find closest point on capsule segment to AABB
        Vector3 closest = closestPointOnSegment(closestStart, closestStart, closestEnd);
        
        // Check distance to capsule
        Vector3 toCapsuleStart = vec3Subtract(capsule.start, closest);
        Vector3 toCapsuleEnd = vec3Subtract(capsule.end, closest);
        
        float distStart = vec3Length(toCapsuleStart);
        float distEnd = vec3Length(toCapsuleEnd);
        
        return (distStart < capsule.radius) || (distEnd < capsule.radius);
    }
    
    static BoundingBox fromModel(Model model, Matrix transform) {
        BoundingBox bbox;
        bbox.min = Vector3(float.max, float.max, float.max);
        bbox.max = Vector3(-float.max, -float.max, -float.max);
        
        if (model.meshes !is null) {
            for (int m = 0; m < model.meshCount; m++) {
                Mesh mesh = model.meshes[m];
                if (mesh.vertices is null) continue;
                
                for (int v = 0; v < mesh.vertexCount; v++) {
                    Vector3 vertex = Vector3(
                        mesh.vertices[v * 3],
                        mesh.vertices[v * 3 + 1],
                        mesh.vertices[v * 3 + 2]
                    );
                    vertex = Vector3Transform(vertex, transform);
                    
                    if (vertex.x < bbox.min.x) bbox.min.x = vertex.x;
                    if (vertex.y < bbox.min.y) bbox.min.y = vertex.y;
                    if (vertex.z < bbox.min.z) bbox.min.z = vertex.z;
                    
                    if (vertex.x > bbox.max.x) bbox.max.x = vertex.x;
                    if (vertex.y > bbox.max.y) bbox.max.y = vertex.y;
                    if (vertex.z > bbox.max.z) bbox.max.z = vertex.z;
                }
            }
        }
        
        return bbox;
    }
}

// ============================================================================
// Player Collision Controller
// ============================================================================

class CollisionController {
    Capsule playerCapsule;
    Vector3 velocity;
    Vector3 position;
    
    struct MeshCollider {
        Model model;
        Matrix transform;
        BoundingBox bbox;
    }
    
    MeshCollider[] colliders;
    
    this(Vector3 pos, float radius, float height) {
        position = pos;
        playerCapsule.start = Vector3(pos.x, pos.y, pos.z);
        playerCapsule.end = Vector3(pos.x, pos.y + height, pos.z);
        playerCapsule.radius = radius;
        colliders = [];
    }
    
    void addCollider(Model model, Matrix transform) {
        MeshCollider collider;
        collider.model = model;
        collider.transform = transform;
        collider.bbox = BoundingBox.fromModel(model, transform);
        colliders ~= collider;
    }
    
    void update(float dt) {
        // Update capsule position
        playerCapsule.start = Vector3(position.x, position.y, position.z);
        playerCapsule.end = Vector3(position.x, position.y + 1.0f, position.z);
        
        // Apply velocity with collision
        Vector3 desiredMove = vec3Scale(velocity, dt);
        
        // X axis movement
        Vector3 moveX = Vector3(desiredMove.x, 0, 0);
        if (!checkCollision(moveX)) {
            position.x += moveX.x;
        }
        
        // Update capsule after X move
        playerCapsule.start.x = position.x;
        playerCapsule.end.x = position.x;
        
        // Z axis movement
        Vector3 moveZ = Vector3(0, 0, desiredMove.z);
        if (!checkCollision(moveZ)) {
            position.z += moveZ.z;
        }
        
        // Update capsule after Z move
        playerCapsule.start.z = position.z;
        playerCapsule.end.z = position.z;
        
        // Y axis movement (gravity/jumping)
        Vector3 moveY = Vector3(0, desiredMove.y, 0);
        if (!checkCollision(moveY)) {
            position.y += moveY.y;
        } else {
            // Landed on something
            if (moveY.y < 0) {
                velocity.y = 0;
            }
        }
        
        // Update capsule after Y move
        playerCapsule.start.y = position.y;
        playerCapsule.end.y = position.y + 1.0f;
    }
    
    bool checkCollision(Vector3 move) {
        Capsule testCapsule;
        testCapsule.start = vec3Add(playerCapsule.start, move);
        testCapsule.end = vec3Add(playerCapsule.end, move);
        testCapsule.radius = playerCapsule.radius;
        
        foreach (collider; colliders) {
            if (collider.model.meshes is null) continue;
            
            // Quick bbox check first
            if (!collider.bbox.overlaps(testCapsule)) {
                continue;
            }
            
            // Full mesh collision
            CollisionResult result = capsuleMeshCollision(testCapsule, collider.model, collider.transform);
            
            if (result.collided && result.penetration > 0.01f) {
                return true;
            }
        }
        
        return false;
    }
    
    bool isGrounded() {
        Vector3 downTest = Vector3(0, -0.2f, 0);
        return checkCollision(downTest);
    }
}
