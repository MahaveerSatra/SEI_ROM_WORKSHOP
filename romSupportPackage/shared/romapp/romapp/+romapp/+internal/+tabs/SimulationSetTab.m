classdef (Hidden) SimulationSetTab < matlab.mixin.SetGet
    %

    % Simulation Set Tab of ROM App
    
    % Copyright 2021-2023 The MathWorks, Inc.    
    
    properties (Access=protected)
        OptionsDialog        
        Tool
        Widgets
    end
    
    properties
        Tab
    end
    methods
        function this = SimulationSetTab(title,parentTag)
            
            this.Tab = matlab.ui.internal.toolstrip.Tab(title);
            this.Tab.Tag = strcat(parentTag,'-tab');
            buildUI(this);
            connectUI(this);
        end

        function update(this)
                       
        end
        
        function delete(this)
            delete(this.OptionsDialog);
        end

    end
    methods (Access=protected)
       
        function buildUI(this)
            import matlab.ui.internal.toolstrip.*
                        
            % Simulation Snapshots
            % Strings
            SimulationSnapshotSectionStr = romapp.internal.resources.getString('lblSimulationSnapshots');
            SimulationSnapshotSection = Section(SimulationSnapshotSectionStr);
            
            column = Column();
            add(SimulationSnapshotSection, column);

            CheckboxStr = romapp.internal.resources.getString('chkCreateLinearizationSnapshots');
            TextFieldStr = romapp.internal.resources.getString('lblSnapshotTimes');
            CheckboxTooltip ='';
            TextFieldTooltip = '';
            SimulationSnapshotCheckBox = CheckBox(CheckboxStr);
            SimulationSnapshotCheckBox.Description = CheckboxTooltip;
            column.add(SimulationSnapshotCheckBox);

            SnapshotEditfield = EditField(TextFieldStr);
            SnapshotEditfield.Description = TextFieldTooltip;
            SnapshotEditfield.Value = '[0]';
            column.add(SnapshotEditfield);
             % Store widgets
            this.Widgets.SimulationSnapshotSection =  struct(...
                'CheckBox',SimulationSnapshotCheckBox,...
                'SnapshotEditfield',SnapshotEditfield);
            
            % ADD SECTIONS
            add(this.Tab, SimulationSnapshotSection);
        end

        function connectUI(this)
            
        end

        function addListeners(this)
                                                     
        end     
        
    end
end

% LocalWords:  Editfield lbl chk
