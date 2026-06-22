using UnityEngine;
using UnityEngine.InputSystem;

public class FpsLook : MonoBehaviour
{
    [Header("References")]
    public Transform body; // Character body/root

    [Header("Mouse Settings")]
    public float sensitivity = 2f;
    public float minPitch = -80f;
    public float maxPitch = 80f;

    [Header("Body Rotation")]
    public float bodyTurnSpeed = 15f;

    private float yaw;
    private float pitch;

    void Start()
    {
        Cursor.lockState = CursorLockMode.Locked;
        Cursor.visible = false;

        // Get current world rotation
        Vector3 euler = transform.rotation.eulerAngles;
        yaw = euler.y;
        pitch = euler.x;

        if (pitch > 180f)
            pitch -= 360f;
    }

    void LateUpdate()
    {
        Vector2 mouseDelta = Mouse.current.delta.ReadValue();

        float mouseX = mouseDelta.x * sensitivity * Time.deltaTime;
        float mouseY = mouseDelta.y * sensitivity * Time.deltaTime;

        yaw += mouseX;
        pitch -= mouseY;
        pitch = Mathf.Clamp(pitch, minPitch, maxPitch);

        // Camera uses world rotation so parent rotation doesn't affect it
        transform.rotation = Quaternion.Euler(pitch, yaw, 0f);

        // Body follows horizontal look direction only
        Quaternion targetBodyRotation = Quaternion.Euler(0f, yaw, 0f);

        body.rotation = Quaternion.Slerp(
            body.rotation,
            targetBodyRotation,
            bodyTurnSpeed * Time.deltaTime
        );
    }
}
