%% Root entry for the digital modulation recognition project
% The full source code is in src/run_modulation_recognition.m.

clear; clc;

projectDir = fileparts(mfilename("fullpath"));
sourceFile = fullfile(projectDir, "src", "run_modulation_recognition.m");

if ~isfile(sourceFile)
    error("Source file not found: %s", sourceFile);
end

run(sourceFile);
