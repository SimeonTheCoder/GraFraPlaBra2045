using System.Collections;
using UnityEngine;

[RequireComponent(typeof(AudioSource))]
public class AdvancedAudioController : MonoBehaviour
{
   
    [Header("Playback Settings")]
    [Tooltip("Automatically play when the scene starts")]
    public bool playOnAwake = false;
 
    [Tooltip("Seconds to wait before playing")]
    [Min(0f)] public float playDelay = 0f;
 
    [Tooltip("Loop the audio clip")]
    public bool loop = false;
 
    [Header("Fade Settings")]
    [Tooltip("Fade in when the audio starts playing")]
    public bool fadeInOnPlay = true;
 
    [Tooltip("Duration of the fade-in in seconds")]
    [Min(0f)] public float fadeInDuration = 1f;
 
    [Tooltip("Fade out before the audio ends or when Stop is called")]
    public bool fadeOutOnStop = true;
 
    [Tooltip("Duration of the fade-out in seconds")]
    [Min(0f)] public float fadeOutDuration = 1f;
 
    [Header("Volume")]
    [Tooltip("Target volume (0 to 1)")]
    [Range(0f, 1f)] public float targetVolume = 1f;
 
    // ── Private ──────────────────────────────────────────────────────────────
 
    private AudioSource _audioSource;
    private Coroutine   _fadeCoroutine;
    private Coroutine   _playCoroutine;
 
    // ── Unity Lifecycle ───────────────────────────────────────────────────────
 
    private void Awake()
    {
        _audioSource = GetComponent<AudioSource>();
        _audioSource.playOnAwake = false; // We manage playback ourselves
        _audioSource.loop        = loop;
 
        // Start silent if we're going to fade in
        if (fadeInOnPlay)
            _audioSource.volume = 0f;
        else
            _audioSource.volume = targetVolume;
    }
 
    private void Start()
    {
        if (playOnAwake)
            Play();
    }
 
    // ── Public API ────────────────────────────────────────────────────────────
 
    /// <summary>Play with optional delay and fade-in.</summary>
    public void Play()
    {
        if (_playCoroutine != null)
            StopCoroutine(_playCoroutine);
 
        _playCoroutine = StartCoroutine(PlayRoutine());
    }
 
    /// <summary>Play a specific clip with optional delay and fade-in.</summary>
    public void Play(AudioClip clip)
    {
        _audioSource.clip = clip;
        Play();
    }
 
    /// <summary>Stop playback, with optional fade-out.</summary>
    public void Stop()
    {
        if (_playCoroutine != null)
        {
            StopCoroutine(_playCoroutine);
            _playCoroutine = null;
        }
 
        if (fadeOutOnStop && _audioSource.isPlaying)
            StartFade(0f, fadeOutDuration, stopAfterFade: true);
        else
            _audioSource.Stop();
    }
 
    /// <summary>Pause playback (volume is kept).</summary>
    public void Pause() => _audioSource.Pause();
 
    /// <summary>Resume a paused clip.</summary>
    public void Resume() => _audioSource.UnPause();
 
    /// <summary>Fade volume to a target over a given duration.</summary>
    public void FadeTo(float volume, float duration)
    {
        volume = Mathf.Clamp01(volume);
        StartFade(volume, duration, stopAfterFade: false);
    }
 
    /// <summary>Fade in from silence to targetVolume.</summary>
    public void FadeIn(float duration = -1f)
    {
        float dur = duration < 0f ? fadeInDuration : duration;
        if (!_audioSource.isPlaying)
        {
            _audioSource.volume = 0f;
            _audioSource.Play();
        }
        StartFade(targetVolume, dur, stopAfterFade: false);
    }
 
    /// <summary>Fade out and optionally stop.</summary>
    public void FadeOut(float duration = -1f, bool stopWhenDone = true)
    {
        float dur = duration < 0f ? fadeOutDuration : duration;
        StartFade(0f, dur, stopAfterFade: stopWhenDone);
    }
 
    // ── Coroutines ────────────────────────────────────────────────────────────
 
    private IEnumerator PlayRoutine()
    {
        // Delay before playing
        if (playDelay > 0f)
            yield return new WaitForSeconds(playDelay);
 
        _audioSource.volume = fadeInOnPlay ? 0f : targetVolume;
        _audioSource.loop   = loop;
        _audioSource.Play();
 
        // Fade in
        if (fadeInOnPlay && fadeInDuration > 0f)
            yield return FadeRoutine(targetVolume, fadeInDuration);
 
        // Auto fade-out before clip ends (only for non-looping clips)
        if (!loop && fadeOutOnStop && _audioSource.clip != null)
        {
            float clipLength    = _audioSource.clip.length;
            float waitTime      = clipLength - fadeOutDuration - (float)_audioSource.timeSamples / _audioSource.clip.frequency;
 
            if (waitTime > 0f)
                yield return new WaitForSeconds(waitTime);
 
            yield return FadeRoutine(0f, fadeOutDuration);
            _audioSource.Stop();
        }
 
        _playCoroutine = null;
    }
 
    private void StartFade(float toVolume, float duration, bool stopAfterFade)
    {
        if (_fadeCoroutine != null)
            StopCoroutine(_fadeCoroutine);
 
        _fadeCoroutine = StartCoroutine(FadeAndMaybeStop(toVolume, duration, stopAfterFade));
    }
 
    private IEnumerator FadeAndMaybeStop(float toVolume, float duration, bool stopAfterFade)
    {
        yield return FadeRoutine(toVolume, duration);
 
        if (stopAfterFade)
            _audioSource.Stop();
 
        _fadeCoroutine = null;
    }
 
    private IEnumerator FadeRoutine(float toVolume, float duration)
    {
        float startVolume = _audioSource.volume;
        float elapsed     = 0f;
 
        while (elapsed < duration)
        {
            elapsed             += Time.deltaTime;
            _audioSource.volume  = Mathf.Lerp(startVolume, toVolume, elapsed / duration);
            yield return null;
        }
 
        _audioSource.volume = toVolume;
    }
}
 
