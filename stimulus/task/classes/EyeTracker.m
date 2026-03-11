classdef EyeTracker < handle
    % Dummy property (logical) is checked on every function call to decide
    % whether to actually run the function.
    
    properties
        dummy
        out_path
        log_file_path 
        edfFile
        destFile
        
        el
        eye_used
    end
    
    methods
        function obj = EyeTracker(win, info)
            
            obj.dummy = ~info.ET;
            obj.out_path = [info.output_dir '/eye'];
            obj.destFile = [info.output_dir, '/eye', info.f_name, '_eye.edf'];
            
            if ~obj.dummy
                obj.setup(win);
                obj.getEyeUsed(); 
            end 
        end

        function setup(obj, win)
            if obj.dummy; return; end
            
            %initialise the eyetracker with default settings
            obj.el = EyelinkInitDefaults(win.h);

            % change some of the settings
            obj.el.backgroundcolour = win.BG_color;
            obj.el.msgfontcolour  = win.black; % I dont want the calibration screen text to show so I am making it the same colour as the background
            obj.el.imgtitlecolour = win.BG_color;
            obj.el.targetbeep = 0; % no beeps during calibration
            obj.el.feedbackbeep = 0;
            obj.el.calibrationtargetcolour= win.white; % colour of calibration dot
            obj.el.calibrationtargetsize= 2; % size of outer dot
            obj.el.calibrationtargetwidth=0.5; % size of inner dot
            obj.el.displayCalResults = 1;
            
            %upload these new settings to the eyetracker. 
            EyelinkUpdateDefaults(obj.el); 
            
            % Initialization of the connection with the Eyelink Gazetracker.
            % exit program if this fails.
            if ~EyelinkInit(0)
                error('Eyelink Init aborted.\n');
            end
            
            % open file to record data to
            % .edf extension will be apended automatically. 
            % file name can have a max length of 8 characters (excluding .edf).
            % if you go beyond this limit, it will not throw an error, you just
            % wont get data at the end. You should put in checks to make sure this
            % isnt violated. I havent done that here. Be smart. Dont be like me. 
            obj.edfFile = 'buf7072a.edf';  % unique filename
            res = Eyelink('OpenFile', obj.edfFile);
            if res~=0
                error('Cannot create EDF file ''%s'' ', obj.edfFile);
            end
            
            % make sure we're still connected.
            if Eyelink('IsConnected')~=1
                error('Not connected to eyetracker');
            end
            
            % Add a header to your output file
            Eyelink('command', 'add_file_preamble_text ''Henry Beale''');

            % This command is crucial to map the gaze positions from the tracker to
            % screen pixel positions to determine fixation
            Eyelink('command','screen_pixel_coords = %ld %ld %ld %ld', 0 ,0 , win.rect(3)-1, win.rect(4)-1);
            Eyelink('message', 'DISPLAY_COORDS %ld %ld %ld %ld', 0, 0, win.rect(3)-1, win.rect(4)-1);

            % set calibration type.
            Eyelink('command', 'calibration_type = HV5'); % HV5 for 5 point calibration, HV9 for 9 point, etc. You will typically use 9 point. Talk to me about when other types will be relevant.
            Eyelink('command', 'generate_default_targets = YES');
            % Eyelink('command', sprintf('calibration_corner_scaling %0.2f', 1*screenAdjustment));
            % Eyelink('command', sprintf('validation_corner_scaling %0.2f', 0.88*screenAdjustment));
            screenAdjustment = 2/3;
            Eyelink('command', sprintf('calibration_area_proportion %0.2f %0.2f', 0.88*(screenAdjustment), 0.83*.9));
            Eyelink('command', sprintf('validation_area_proportion %0.2f %0.2f', 0.88*(screenAdjustment), 0.83*.9));

            % set parser (conservative saccade thresholds)
            Eyelink('command', 'recording_parse_type = GAZE');
            Eyelink('command', 'saccade_velocity_threshold = 22');
            Eyelink('command', 'saccade_acceleration_threshold = 3800');
            Eyelink('command', 'saccade_motion_threshold = 0.0');
            Eyelink('command', 'saccade_pursuit_fixup = 60');
            Eyelink('command', 'fixation_update_interval = 0');

            % set things to sample (these are defaults)
            Eyelink('command', 'file_event_filter = LEFT,RIGHT,FIXATION,SACCADE,BLINK,MESSAGE,BUTTON,FIXUPDATE,INPUT');
            Eyelink('command', 'file_sample_data  = LEFT,RIGHT,GAZE,HREF,AREA,GAZERES,STATUS,INPUT');
            % set link data (used for gaze cursor) - Dont think we strictly need
            Eyelink('command', 'link_event_filter = LEFT,RIGHT,FIXATION,SACCADE,BLINK,MESSAGE,BUTTON,FIXUPDATE,INPUT');
            Eyelink('command', 'link_sample_data  = LEFT,RIGHT,GAZE,GAZERES,AREA,STATUS,INPUT');
        end
        
        function message(obj, message)
            if obj.dummy; return; end
            
            Eyelink('Message', message); 
        end
        
        function calibrate(obj)
            % Run calibration
            if obj.dummy; return; end
            
            EyelinkDoTrackerSetup(obj.el);
        end
        
        function getEyeUsed(obj)
            % Find out which eye we're tracking
            if obj.dummy; return; end
            
            obj.eye_used = Eyelink('EyeAvailable'); % get eye that's tracked
            if obj.eye_used == obj.el.BINOCULAR || obj.eye_used == -1 % if both eyes are tracked or if we dont know
                obj.eye_used = obj.el.RIGHT_EYE; % use right eye
            end
        end
        
        function boothStatusMessage(obj, input_str) 
            % Displays on the eyetracker screen what the trial is (and any
            % other information you want to put here)
            
            if obj.dummy; return; end
            % Format for Eyelink 
            message = sprintf('record_status_message "%s"', input_str);
            Eyelink('command', message);
        end
        
        function startRecording(obj)
            if obj.dummy; return; end
%             WaitSecs(0.1);
            Eyelink('StartRecording'); 
            WaitSecs(0.1); 
            
            obj.getEyeUsed();
        end
        
        function stopRecording(obj)
            if obj.dummy; return; end
            Eyelink('StopRecording');
        end
        
        function saveData(obj)
            if obj.dummy; return; end
            
            obj.stopRecording();
            
            Eyelink('Command', 'set_idle_mode'); 
            WaitSecs(0.5);
            Eyelink('CloseFile'); 
            
            % Retrieve file
            try 
                fprintf('Receiving data file ''%s''\n', obj.edfFile);
                status=Eyelink('ReceiveFile',[],obj.out_path,1);
                fprintf('ReceiveFile status %d\n', status);
                
                movefile([obj.out_path '/', obj.edfFile], obj.destFile)
                fprintf('Data file ''%s'' can be found in ''%s''\n', obj.edfFile, obj.out_path);
                
            catch
                disp('Problem receiving Eyelink data file')
            end
            Eyelink('Shutdown');
        end
    end
    methods(Static)
        function obj = loadobj(s)
            % Allows a saved object to be loaded back as an object. 
            obj = s; 
        end
    end
end