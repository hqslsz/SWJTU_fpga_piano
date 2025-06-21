import mido
import time 
MIDI_FILE_PATH = "C:/Users/wlrh_/Desktop/midi/lemon.mid"
def parse_midi_file(filepath):
    try:
        mid = mido.MidiFile(filepath)
        print(f"Successfully loaded MIDI file: {filepath}")
        print(f"Type: {mid.type}")
        print(f"Ticks per beat: {mid.ticks_per_beat}")
        print(f"Tracks: {len(mid.tracks)}")
        print("-" * 30)

        if not mid.tracks:
            print("Error: MIDI file has no tracks!")
            return
        for track_index, track in enumerate(mid.tracks):
            print(f"\n--- Parsing Track {track_index} ---")
            print(f"Track Name (if any): {track.name}")
            absolute_time_seconds_track = 0.0 
            if track_index == 0:
                for msg_meta_check in track:
                    if msg_meta_check.is_meta and msg_meta_check.type == 'set_tempo':
                        current_tempo = msg_meta_check.tempo
                        print(f"  Initial Tempo found in Track 0: {current_tempo} us/beat (approx {mido.tempo2bpm(current_tempo):.2f} BPM)")
                        break # Assuming one tempo message at the start is enough for global tempo
            print(f"Using tempo: {current_tempo} us/beat (approx {mido.tempo2bpm(current_tempo):.2f} BPM) for this track's time calculations.")
            for i, msg in enumerate(track):
                delta_time_seconds = mido.tick2second(msg.time, mid.ticks_per_beat, current_tempo)
                absolute_time_seconds_track += delta_time_seconds
                print(f"  Msg {i} in Track {track_index}: {msg} (Delta: {msg.time} ticks / {delta_time_seconds:.4f} s, Abs Track Time: {absolute_time_seconds_track:.4f} s)")
                if msg.is_meta:
                    if msg.type == 'set_tempo':
                        # Tempo can change mid-track, though less common for the main tempo
                        current_tempo = msg.tempo
                        print(f"    Meta: Tempo changed to {current_tempo} us/beat (approx {mido.tempo2bpm(current_tempo):.2f} BPM)")
                    elif msg.type == 'time_signature':
                        print(f"    Meta: Time Signature: {msg.numerator}/{msg.denominator}, clocks: {msg.clocks_per_click}, 32nds: {msg.notated_32nd_notes_per_beat}")
                    elif msg.type == 'track_name':
                        print(f"    Meta: Track Name: {msg.name}")   
                elif msg.type == 'note_on':
                    if msg.velocity > 0:
                        print(f"    NOTE ON: Note={msg.note}, Velocity={msg.velocity}, Channel={msg.channel}")
                    else:
                        print(f"    NOTE OFF (from note_on vel=0): Note={msg.note}, Channel={msg.channel}")
                
                elif msg.type == 'note_off':
                    print(f"    NOTE OFF: Note={msg.note}, Velocity={msg.velocity}, Channel={msg.channel}")
                
                elif msg.type == 'program_change':
                    print(f"    PROGRAM CHANGE: Program={msg.program}, Channel={msg.channel}")
                
                elif msg.type == 'control_change':
                    print(f"    CONTROL CHANGE: Control={msg.control}, Value={msg.value}, Channel={msg.channel}")
    except FileNotFoundError:
        print(f"Error: MIDI file not found at {filepath}")
    except mido.KeySignatureError as e: # Catch specific mido errors if needed
        print(f"MIDI parsing error (KeySignatureError): {e} - This can happen with some malformed MIDI files or complex key signatures not fully handled by default.")
    except Exception as e:
        print(f"An error occurred: {e}")
if __name__ == "__main__":
    parse_midi_file(MIDI_FILE_PATH)

 