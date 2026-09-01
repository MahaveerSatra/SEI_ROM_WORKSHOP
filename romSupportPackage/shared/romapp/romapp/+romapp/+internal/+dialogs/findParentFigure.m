function fig = findParentFigure(parent)
    if isa(parent,'matlab.ui.Figure')
        fig = parent;
    else
        %Recurse up ui tree
        fig = romapp.internal.dialogs.findParentFigure(parent.Parent);
    end
end