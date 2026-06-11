; EnigmaSuite v1.4 - Fast Workflow
; Removed "Press Any Key" pauses for quick menu navigation
; Target: MASM with Irvine32 Library

.386
.model flat, stdcall
.STACK 4096

; --- WINDOWS API PROTOTYPES ---
CreateFileA    PROTO, lpFileName:PTR BYTE, dwDesiredAccess:DWORD, dwShareMode:DWORD, lpSecurityAttributes:DWORD, dwCreationDisposition:DWORD, dwFlagsAndAttributes:DWORD, hTemplateFile:DWORD
ReadFile       PROTO, hFile:DWORD, lpBuffer:PTR BYTE, nNumberOfBytesToRead:DWORD, lpNumberOfBytesRead:PTR DWORD, lpOverlapped:PTR DWORD
WriteFile      PROTO, hFile:DWORD, lpBuffer:PTR BYTE, nNumberOfBytesToWrite:DWORD, lpNumberOfBytesWritten:PTR DWORD, lpOverlapped:PTR DWORD
CloseHandle    PROTO, hObject:DWORD

ExitProcess PROTO, dwExitCode:DWORD
INCLUDE Irvine32.inc

; --- CONSTANTS ---
GENERIC_READ     EQU 80000000h
GENERIC_WRITE    EQU 40000000h
FILE_SHARE_READ  EQU 00000001h
FILE_SHARE_WRITE EQU 00000002h
OPEN_EXISTING    EQU 3
CREATE_ALWAYS    EQU 2
NULL             EQU 0
INVALID_HANDLE_VALUE EQU -1

; ---------------------------------------------------------
; DATA SECTION
; ---------------------------------------------------------
.data

; --- Menu Strings ---
menuPrompt     BYTE "=== ENIGMA SUITE v1.4 ===", 0dh, 0ah
               BYTE "1. Encrypt a File", 0dh, 0ah
               BYTE "2. Decrypt a File", 0dh, 0ah
               BYTE "3. Analyze Last Output (Frequency)", 0dh, 0ah
               BYTE "4. Exit", 0dh, 0ah, 0
choicePrompt   BYTE "Enter choice: ", 0

; Encryption Strings
msgSrcFile     BYTE "Enter plaintext filename (e.g., plaintext.txt): ", 0
msgDstFile     BYTE "Enter output filename (e.g., ciphertext.txt): ", 0
msgKey         BYTE "Enter 3-char key (A-Z, e.g., AAA): ", 0
msgDone        BYTE 0dh, 0ah, "Encryption Complete.", 0dh, 0ah, 0
msgStatus      BYTE "Bytes processed: ", 0

; Decryption Strings
msgDecSrcFile  BYTE "Enter ciphertext filename (e.g., ciphertext.txt): ", 0
msgDecDstFile  BYTE "Enter output filename (e.g., recovered.txt): ", 0
msgDecKey      BYTE "Enter the 3-char Key used for Encryption: ", 0
msgDecDone     BYTE 0dh, 0ah, "Decryption Complete.", 0dh, 0ah, 0

; Error Strings
msgError       BYTE "Error opening file.", 0dh, 0ah, 0

; Analysis Strings
anlHeader      BYTE 0dh, 0ah, "--- FREQUENCY ANALYSIS ---", 0dh, 0ah, 0
charLabel      BYTE ": ", 0
barChar        BYTE '#', 0
newline        BYTE 0dh, 0ah, 0

; Enigma Machine Configuration
rotorI       BYTE "EKMFLGDQVZNTOWYHXUSPAIBRCJ"
rotorII      BYTE "AJDKSIRUXBLHWTMCQGPNVOEYFZ"
rotorIII     BYTE "BDFHJLCPRTXVZNYEIWGAKMUSQO"
reflectorB   BYTE "YRUHQSLDPXNGOKMIEBFZCWVJAT"
plugboard    BYTE "ABCDEFGHIJKLMNOPQRSTUVWXYZ" 

; State Variables
posR1        BYTE ?
posR2        BYTE ?
posR3        BYTE ?

BUFFER_SIZE  EQU 10240
fileBuffer   BYTE BUFFER_SIZE DUP(?)
bytesRead    DWORD ?
bytesWritten DWORD ?
freqCount    DWORD 26 DUP(0)

; ---------------------------------------------------------
; CODE SECTION
; ---------------------------------------------------------
.code
main PROC
    call Clrscr
    mov posR1, 0
    mov posR2, 0
    mov posR3, 0

MenuLoop:
    mov edx, OFFSET menuPrompt
    call WriteString
    mov edx, OFFSET choicePrompt
    call WriteString
    
    call ReadDec
    
    cmp eax, 1
    je OptionEncrypt
    cmp eax, 2
    je OptionDecrypt
    cmp eax, 3
    je OptionAnalyze
    cmp eax, 4
    je ProgramExit
    jmp MenuLoop

OptionEncrypt:
    call EncryptFileProcedure
    jmp MenuLoop

OptionDecrypt:
    call DecryptFileProcedure
    jmp MenuLoop

OptionAnalyze:
    call AnalyzeFrequencyProcedure
    jmp MenuLoop

ProgramExit:
    INVOKE ExitProcess, 0
main ENDP

; ---------------------------------------------------------
; PROCEDURE: EncryptFileProcedure
; ---------------------------------------------------------
EncryptFileProcedure PROC
    LOCAL srcFilename[50]:BYTE, dstFilename[50]:BYTE, userKey[5]:BYTE
    LOCAL hFileSrc:DWORD, hFileDst:DWORD
    
    ; 1. Get Inputs
    mov edx, OFFSET msgSrcFile
    call WriteString
    lea edx, srcFilename
    mov ecx, 50
    call ReadString

    mov edx, OFFSET msgDstFile
    call WriteString
    lea edx, dstFilename
    mov ecx, 50
    call ReadString

    mov edx, OFFSET msgKey
    call WriteString
    lea edx, userKey
    mov ecx, 5
    call ReadString

    ; 2. Set Key
    lea esi, userKey
    mov al, [esi]
    call CharToIndex
    mov posR1, al
    mov al, [esi+1]
    call CharToIndex
    mov posR2, al
    mov al, [esi+2]
    call CharToIndex
    mov posR3, al

    ; 3. Open Source (Allow Read Sharing)
    INVOKE CreateFileA, ADDR srcFilename, GENERIC_READ, FILE_SHARE_READ, NULL, OPEN_EXISTING, 0, NULL
    cmp eax, INVALID_HANDLE_VALUE
    je ErrorHandler
    mov hFileSrc, eax

    ; 4. Read
    INVOKE ReadFile, hFileSrc, ADDR fileBuffer, BUFFER_SIZE, ADDR bytesRead, NULL
    INVOKE CloseHandle, hFileSrc

    ; 5. Encrypt
    mov ecx, bytesRead
    mov esi, OFFSET fileBuffer
    mov edi, 0
EncryptLoop:
    push ecx
    mov al, [esi + edi]
    cmp al, 'A'
    jb  SkipEnc
    cmp al, 'Z'
    ja  SkipEnc
    call ProcessEnigmaChar
    mov [esi + edi], al
SkipEnc:
    inc edi
    pop ecx
    loop EncryptLoop

    ; 6. Write Dest (Allow Write Sharing)
    INVOKE CreateFileA, ADDR dstFilename, GENERIC_WRITE, FILE_SHARE_WRITE, NULL, CREATE_ALWAYS, 0, NULL
    cmp eax, INVALID_HANDLE_VALUE
    je ErrorHandler
    mov hFileDst, eax

    INVOKE WriteFile, hFileDst, ADDR fileBuffer, bytesRead, ADDR bytesWritten, NULL
    INVOKE CloseHandle, hFileDst

    ; 7. Status
    mov edx, OFFSET msgDone
    call WriteString
    mov edx, OFFSET msgStatus
    call WriteString
    mov eax, bytesWritten
    call WriteDec
    mov edx, OFFSET newline ; Just newline to separate menu
    call WriteString
    ret

ErrorHandler:
    mov edx, OFFSET msgError
    call WriteString
    ret
EncryptFileProcedure ENDP

; ---------------------------------------------------------
; PROCEDURE: DecryptFileProcedure
; ---------------------------------------------------------
DecryptFileProcedure PROC
    LOCAL srcFilename[50]:BYTE, dstFilename[50]:BYTE, userKey[5]:BYTE
    LOCAL hFileSrc:DWORD, hFileDst:DWORD
    
    ; 1. Get Inputs
    mov edx, OFFSET msgDecSrcFile
    call WriteString
    lea edx, srcFilename
    mov ecx, 50
    call ReadString

    mov edx, OFFSET msgDecDstFile
    call WriteString
    lea edx, dstFilename
    mov ecx, 50
    call ReadString

    mov edx, OFFSET msgDecKey
    call WriteString
    lea edx, userKey
    mov ecx, 5
    call ReadString

    ; 2. Set Key
    lea esi, userKey
    mov al, [esi]
    call CharToIndex
    mov posR1, al
    mov al, [esi+1]
    call CharToIndex
    mov posR2, al
    mov al, [esi+2]
    call CharToIndex
    mov posR3, al

    ; 3. Open Source
    INVOKE CreateFileA, ADDR srcFilename, GENERIC_READ, FILE_SHARE_READ, NULL, OPEN_EXISTING, 0, NULL
    cmp eax, INVALID_HANDLE_VALUE
    je ErrorHandler
    mov hFileSrc, eax

    ; 4. Read
    INVOKE ReadFile, hFileSrc, ADDR fileBuffer, BUFFER_SIZE, ADDR bytesRead, NULL
    INVOKE CloseHandle, hFileSrc

    ; 5. Decrypt
    mov ecx, bytesRead
    mov esi, OFFSET fileBuffer
    mov edi, 0
DecryptLoop:
    push ecx
    mov al, [esi + edi]
    cmp al, 'A'
    jb  SkipDec
    cmp al, 'Z'
    ja  SkipDec
    call ProcessEnigmaChar
    mov [esi + edi], al
SkipDec:
    inc edi
    pop ecx
    loop DecryptLoop

    ; 6. Write Dest
    INVOKE CreateFileA, ADDR dstFilename, GENERIC_WRITE, FILE_SHARE_WRITE, NULL, CREATE_ALWAYS, 0, NULL
    cmp eax, INVALID_HANDLE_VALUE
    je ErrorHandler
    mov hFileDst, eax

    INVOKE WriteFile, hFileDst, ADDR fileBuffer, bytesRead, ADDR bytesWritten, NULL
    INVOKE CloseHandle, hFileDst

    ; 7. Status
    mov edx, OFFSET msgDecDone
    call WriteString
    mov edx, OFFSET msgStatus
    call WriteString
    mov eax, bytesWritten
    call WriteDec
    mov edx, OFFSET newline
    call WriteString
    ret

ErrorHandler:
    mov edx, OFFSET msgError
    call WriteString
    ret
DecryptFileProcedure ENDP

; ---------------------------------------------------------
; PROCEDURE: ProcessEnigmaChar
; ---------------------------------------------------------
ProcessEnigmaChar PROC
    LOCAL currIdx:BYTE
    call CharToIndex
    mov currIdx, al

    ; Forward
    movzx ebx, currIdx
    mov al, plugboard[ebx]
    call CharToIndex
    mov currIdx, al
    call Rotor3Forward
    mov currIdx, al
    call Rotor2Forward
    mov currIdx, al
    call Rotor1Forward
    mov currIdx, al
    movzx ebx, currIdx
    mov al, reflectorB[ebx]
    call CharToIndex
    mov currIdx, al
    
    ; Reverse
    call Rotor1Reverse
    mov currIdx, al
    call Rotor2Reverse
    mov currIdx, al
    call Rotor3Reverse
    mov currIdx, al
    movzx ebx, currIdx
    mov al, plugboard[ebx]
    call CharToIndex
    mov currIdx, al

    mov al, currIdx
    call IndexToChar

    ; Step Rotors
    inc posR3
    cmp posR3, 26
    jb  NS2
    mov posR3, 0
    inc posR2
    cmp posR2, 26
    jb  NS2
    mov posR2, 0
    inc posR1
    cmp posR1, 26
    jb  NS2
    mov posR1, 0
NS2:
    ret
ProcessEnigmaChar ENDP

; ---------------------------------------------------------
; PROCEDURE: AnalyzeFrequencyProcedure
; ---------------------------------------------------------
AnalyzeFrequencyProcedure PROC
    call Clrscr
    mov edx, OFFSET anlHeader
    call WriteString
    mov ecx, 26
    mov edi, OFFSET freqCount
    mov eax, 0
ResetLoop:
    mov [edi], eax
    add edi, 4
    loop ResetLoop

    mov ecx, bytesRead
    cmp ecx, 0
    jz DoneAnalysis
    mov esi, OFFSET fileBuffer
CountLoop:
    mov al, [esi]
    cmp al, 'A'
    jb  NextCount
    cmp al, 'Z'
    ja  NextCount
    sub al, 'A'
    movzx ebx, al
    inc freqCount[ebx*4]
NextCount:
    inc esi
    loop CountLoop

    mov ecx, 0
PrintLoop:
    push ecx
    mov eax, ecx
    call IndexToChar
    call WriteChar
    mov edx, OFFSET charLabel
    call WriteString
    mov eax, freqCount[ecx*4]
    call WriteDec
    mov edx, OFFSET newline
    call WriteString
    mov eax, freqCount[ecx*4]
    mov edx, 0
    mov ebx, 10
    div ebx
    mov ecx, eax
    cmp ecx, 0
    jz  NoBar
    cmp ecx, 40
    jle PrintBar
    mov ecx, 40
PrintBar:
    mov al, '#'
    call WriteChar
    loop PrintBar
NoBar:
    mov edx, OFFSET newline
    call WriteString
    pop ecx
    inc ecx
    cmp ecx, 26
    jl  PrintLoop
DoneAnalysis:
    mov edx, OFFSET newline ; Newline before returning to menu
    call WriteString
    ret
AnalyzeFrequencyProcedure ENDP

; ---------------------------------------------------------
; ROTOR HELPERS
; ---------------------------------------------------------
Rotor3Forward PROC
    add al, posR3
    call Mod26
    movzx ebx, al
    mov al, rotorIII[ebx]
    call CharToIndex
    sub al, posR3
    call Mod26
    ret
Rotor3Forward ENDP

Rotor2Forward PROC
    add al, posR2
    call Mod26
    movzx ebx, al
    mov al, rotorII[ebx]
    call CharToIndex
    sub al, posR2
    call Mod26
    ret
Rotor2Forward ENDP

Rotor1Forward PROC
    add al, posR1
    call Mod26
    movzx ebx, al
    mov al, rotorI[ebx]
    call CharToIndex
    sub al, posR1
    call Mod26
    ret
Rotor1Forward ENDP

; --- FIXED REVERSE LOGIC ---
Rotor3Reverse PROC
    add al, posR3
    call Mod26
    call IndexToChar
    mov bl, al
    
    mov ecx, 26
    mov edx, 0
SearchR3:
    mov al, rotorIII[edx]
    cmp al, bl
    je  FoundR3
    inc edx
    loop SearchR3
FoundR3:
    mov eax, edx
    sub al, posR3
    call Mod26
    ret
Rotor3Reverse ENDP

Rotor2Reverse PROC
    add al, posR2
    call Mod26
    call IndexToChar
    mov bl, al
    
    mov ecx, 26
    mov edx, 0
SearchR2:
    mov al, rotorII[edx]
    cmp al, bl
    je  FoundR2
    inc edx
    loop SearchR2
FoundR2:
    mov eax, edx
    sub al, posR2
    call Mod26
    ret
Rotor2Reverse ENDP

Rotor1Reverse PROC
    add al, posR1
    call Mod26
    call IndexToChar
    mov bl, al
    
    mov ecx, 26
    mov edx, 0
SearchR1:
    mov al, rotorI[edx]
    cmp al, bl
    je  FoundR1
    inc edx
    loop SearchR1
FoundR1:
    mov eax, edx
    sub al, posR1
    call Mod26
    ret
Rotor1Reverse ENDP

; ---------------------------------------------------------
; UTILS
; ---------------------------------------------------------
CharToIndex PROC
    sub al, 'A'
    ret
CharToIndex ENDP

IndexToChar PROC
    add al, 'A'
    ret
IndexToChar ENDP

Mod26 PROC
    cmp al, 0
    jge PosMod
    add al, 26
PosMod:
    cmp al, 26
    jl  ModDone
    sub al, 26
    jmp PosMod
ModDone:
    ret
Mod26 ENDP

END main