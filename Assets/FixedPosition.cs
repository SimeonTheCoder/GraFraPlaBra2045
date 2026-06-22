using UnityEngine;

public class BecomeHidden : MonoBehaviour
{
    // Update is called once per frame
    void LateUpdate()
    {
        transform.localScale = Vector3.zero;
    }
}
