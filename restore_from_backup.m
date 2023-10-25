function loaded = restore_from_backup(file, interactive)
% LOADED = RESTORE_FROM_BACKUP(FILE, INTERACTIVE) - load FILE (if exists)
% onto caller workspace, optionally after QUESTDLG.

    validateattributes(file,{'char','string'},{})
    validateattributes(interactive,'logical',{'scalar'})

    loaded = false;
    if isfile(file)
        if interactive
            switch questdlg(['Do you want to resume from ', file, '?'])
                case 'Yes'
                    evalin('caller', ['load("' file '" )'])
                    loaded = true;
                case 'No'
                case 'Cancel', error('Stopped by user')
            end
        else
            disp(['Attempting to resume from ', file]);
            evalin('caller', ['load("' file '" )'])
            loaded = true;
        end
    end
end