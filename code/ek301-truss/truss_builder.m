function truss_builder()
%TRUSS_BUILDER Interactive GUI for building and analyzing 2D trusses.
%   Designed for EK301 Truss Design Project (Spring 2026).
%   Click to place joints, connect members, assign supports/loads, then solve.
%   Real-time constraint validation and member length display.
%
%   Usage: Run truss_builder() in MATLAB command window.

%% ========================================================================
%  STATE VARIABLES (shared by all nested functions via closure)
%  ========================================================================

% Geometry
joints         = zeros(0, 2);   % Nx2 [x y] per row
members        = zeros(0, 2);   % Mx2 [j1 j2] per row (1-indexed)

% Boundary conditions
pin_joint      = [];
roller_joint   = [];
load_joint     = [];
load_magnitude = 32;            % oz default

% Interaction state
mode           = 'add_joint';
selected_joint = [];             % first click in add_member mode
dragging_joint = [];
drag_active    = false;

% Solution state
solved          = false;
member_forces   = [];
reaction_forces = [];
critical_member = [];
W_max           = [];
W_max_low       = [];
member_lengths_solved = [];

% Undo
undo_stack = {};

% Rubber-band line handle
hRubberBand = [];

%% ========================================================================
%  PROJECT CONSTRAINTS
%  ========================================================================
MIN_MEMBER_LEN  = 6;
MAX_MEMBER_LEN  = 14;
MIN_SPAN        = 26;
MAX_SPAN        = 30;
MIN_LOAD_DX     = 9;
MAX_LOAD_DX     = 11;
MIN_LOAD_DY     = 0;
MAX_LOAD_DY     = 2;
MAX_TOTAL_LEN   = 120;   % 10 ft

% Buckling parameters
C_BUCKLE = 37.5;
L0       = 10;
ALPHA    = 2;
U_FIT    = 10;

% Cost parameters
CL = 1;
CJ = 10;

%% ========================================================================
%  CREATE FIGURE AND UI
%  ========================================================================
hFig = figure('Name', 'EK301 Truss Builder', 'NumberTitle', 'off', ...
    'Position', [80 80 1250 720], 'Color', [0.94 0.94 0.94], ...
    'MenuBar', 'none', 'ToolBar', 'figure', ...
    'WindowButtonDownFcn', @cb_mouse_down, ...
    'WindowButtonMotionFcn', @cb_mouse_move, ...
    'WindowButtonUpFcn', @cb_mouse_up, ...
    'KeyPressFcn', @cb_key_press, ...
    'CloseRequestFcn', @(~,~) delete(hFig));

% --- Toolbar buttons ---
btn_w = 90; btn_h = 30; btn_y = 680; gap = 5;
btn_x = 10;

mode_buttons = {};
button_defs = {
    'Add Joint (J)',  'add_joint';
    'Add Member (M)', 'add_member';
    'Set Pin (P)',    'set_pin';
    'Set Roller (R)', 'set_roller';
    'Set Load (L)',   'set_load';
    'Move (V)',       'move_joint';
    'Delete (D)',     'delete'
};

for i = 1:size(button_defs, 1)
    mode_buttons{i} = uicontrol(hFig, 'Style', 'togglebutton', ...
        'String', button_defs{i,1}, 'Position', [btn_x btn_y btn_w btn_h], ...
        'FontSize', 8, 'UserData', button_defs{i,2}, ...
        'Callback', @cb_mode_button);
    btn_x = btn_x + btn_w + gap;
end
mode_buttons{1}.Value = 1;  % Add Joint selected by default

% Action buttons (not toggle)
btn_x = btn_x + 15;
uicontrol(hFig, 'Style', 'pushbutton', 'String', 'SOLVE (S)', ...
    'Position', [btn_x btn_y 85 btn_h], 'FontSize', 8, 'FontWeight', 'bold', ...
    'BackgroundColor', [0.6 0.9 0.6], 'Callback', @(~,~) solve_truss());
btn_x = btn_x + 90;

uicontrol(hFig, 'Style', 'pushbutton', 'String', 'Export .mat', ...
    'Position', [btn_x btn_y 85 btn_h], 'FontSize', 8, ...
    'Callback', @(~,~) cb_export());
btn_x = btn_x + 90;

uicontrol(hFig, 'Style', 'pushbutton', 'String', 'Clear All', ...
    'Position', [btn_x btn_y 75 btn_h], 'FontSize', 8, ...
    'BackgroundColor', [1 0.8 0.8], 'Callback', @(~,~) cb_clear());
btn_x = btn_x + 80;

uicontrol(hFig, 'Style', 'pushbutton', 'String', 'Undo (Z)', ...
    'Position', [btn_x btn_y 75 btn_h], 'FontSize', 8, ...
    'Callback', @(~,~) cb_undo());

% --- Mode label ---
hModeLabel = uicontrol(hFig, 'Style', 'text', 'String', 'Mode: ADD JOINT', ...
    'Position', [10 650 300 22], 'FontSize', 11, 'FontWeight', 'bold', ...
    'HorizontalAlignment', 'left', 'BackgroundColor', [0.94 0.94 0.94], ...
    'ForegroundColor', [0.1 0.3 0.7]);

% --- Canvas axes ---
hAx = axes(hFig, 'Units', 'pixels', 'Position', [55 50 830 590]);
axis(hAx, 'equal');
set(hAx, 'XLim', [-2 38], 'YLim', [-3 18]);
xlabel(hAx, 'X (inches)'); ylabel(hAx, 'Y (inches)');
grid(hAx, 'on');
hold(hAx, 'on');

% --- Status panel ---
hPanel = uipanel(hFig, 'Title', 'Status', 'FontSize', 10, 'FontWeight', 'bold', ...
    'Units', 'pixels', 'Position', [910 50 330 620]);

hStatusText = uicontrol(hPanel, 'Style', 'text', 'String', '', ...
    'Position', [5 5 315 590], 'FontSize', 9, 'FontName', 'Consolas', ...
    'HorizontalAlignment', 'left', 'VerticalAlignment', 'top', ...
    'BackgroundColor', 'white', 'Max', 2);

%% ========================================================================
%  INITIAL DRAW
%  ========================================================================
redraw();

%% ========================================================================
%  NESTED FUNCTIONS
%  ========================================================================

% ----- REDRAW (central visualization) -----
function redraw()
    xl = get(hAx, 'XLim'); yl = get(hAx, 'YLim');
    cla(hAx);
    hold(hAx, 'on');

    % Grid dots
    gx = floor(xl(1)):1:ceil(xl(2));
    gy = floor(yl(1)):1:ceil(yl(2));
    [GX, GY] = meshgrid(gx, gy);
    plot(hAx, GX(:), GY(:), '.', 'Color', [0.85 0.85 0.85], 'MarkerSize', 3);

    % Baseline at y=0
    plot(hAx, xl, [0 0], '--', 'Color', [0.6 0.6 0.6], 'LineWidth', 0.5);

    J = size(joints, 1);
    M_count = size(members, 1);

    % Compute current member lengths
    mem_lens = zeros(M_count, 1);
    for mi = 1:M_count
        j1 = members(mi,1); j2 = members(mi,2);
        mem_lens(mi) = norm(joints(j2,:) - joints(j1,:));
    end

    % Draw members
    for mi = 1:M_count
        j1 = members(mi,1); j2 = members(mi,2);
        x1 = joints(j1,1); y1 = joints(j1,2);
        x2 = joints(j2,1); y2 = joints(j2,2);
        L_m = mem_lens(mi);

        if solved && ~isempty(member_forces)
            % Solved colors
            if mi == critical_member
                clr = [1 0.5 0]; lw = 4;       % orange critical
            elseif member_forces(mi) < -1e-6
                clr = [0.8 0 0]; lw = 2;       % red compression
            elseif member_forces(mi) > 1e-6
                clr = [0 0.4 0.8]; lw = 2;     % blue tension
            else
                clr = [0.6 0.6 0.6]; lw = 1.5; % gray zero
            end
        else
            % Unsolved colors — red if out of range
            if L_m < MIN_MEMBER_LEN || L_m > MAX_MEMBER_LEN
                clr = [0.9 0 0]; lw = 2.5;
            else
                clr = [0.15 0.15 0.15]; lw = 1.8;
            end
        end

        plot(hAx, [x1 x2], [y1 y2], '-', 'Color', clr, 'LineWidth', lw);

        % Label at midpoint (offset perpendicular)
        mx = (x1+x2)/2; my = (y1+y2)/2;
        dx = x2-x1; dy = y2-y1;
        perp = [-dy, dx] / max(L_m, 0.01) * 0.5;
        lx = mx + perp(1); ly = my + perp(2);

        if solved && ~isempty(member_forces)
            f = member_forces(mi);
            if f > 1e-6, tc = 'T';
            elseif f < -1e-6, tc = 'C';
            else, tc = '0'; end
            lbl = sprintf('m%d\n%.1f%s', mi, abs(f), tc);
        else
            lbl = sprintf('m%d\n%.1fin', mi, L_m);
        end
        text(hAx, lx, ly, lbl, 'FontSize', 7, 'Color', clr, ...
            'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', ...
            'BackgroundColor', [1 1 1 0.7], 'EdgeColor', 'none', 'Margin', 1);
    end

    % Draw joints
    if J > 0
        plot(hAx, joints(:,1), joints(:,2), 'ko', 'MarkerSize', 8, ...
            'MarkerFaceColor', [0.2 0.2 0.2]);
        for ji = 1:J
            text(hAx, joints(ji,1), joints(ji,2)+0.6, sprintf('J%d', ji), ...
                'FontSize', 8, 'FontWeight', 'bold', ...
                'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', ...
                'Color', [0.1 0.1 0.5]);
        end
    end

    % Draw pin support
    if ~isempty(pin_joint) && pin_joint <= J
        px = joints(pin_joint, 1); py = joints(pin_joint, 2);
        % Triangle pointing up
        tri_x = px + [-0.8 0.8 0]; tri_y = py + [-1.2 -1.2 -0.2];
        fill(hAx, tri_x, tri_y, [0.2 0.7 0.2], 'EdgeColor', [0 0.5 0], 'LineWidth', 1.5);
        text(hAx, px, py-1.5, 'PIN', 'FontSize', 7, 'FontWeight', 'bold', ...
            'HorizontalAlignment', 'center', 'Color', [0 0.5 0]);
    end

    % Draw roller support
    if ~isempty(roller_joint) && roller_joint <= J
        rx = joints(roller_joint, 1); ry = joints(roller_joint, 2);
        theta = linspace(0, 2*pi, 30);
        fill(hAx, rx + 0.5*cos(theta), ry - 0.8 + 0.4*sin(theta), ...
            [0.2 0.7 0.2], 'EdgeColor', [0 0.5 0], 'LineWidth', 1.5);
        text(hAx, rx, ry-1.5, 'ROLLER', 'FontSize', 7, 'FontWeight', 'bold', ...
            'HorizontalAlignment', 'center', 'Color', [0 0.5 0]);
    end

    % Draw load arrow
    if ~isempty(load_joint) && load_joint <= J
        lx_j = joints(load_joint, 1); ly_j = joints(load_joint, 2);
        quiver(hAx, lx_j, ly_j+2.5, 0, -2, 0, 'Color', [0.8 0 0], ...
            'LineWidth', 2.5, 'MaxHeadSize', 1);
        text(hAx, lx_j+0.3, ly_j+3, sprintf('W=%g oz', load_magnitude), ...
            'FontSize', 9, 'FontWeight', 'bold', 'Color', [0.8 0 0]);
    end

    % Highlight selected joint in add_member mode
    if ~isempty(selected_joint) && selected_joint <= J
        sx = joints(selected_joint, 1); sy = joints(selected_joint, 2);
        plot(hAx, sx, sy, 'o', 'MarkerSize', 16, 'Color', [0 0.8 0.8], ...
            'LineWidth', 2.5);
    end

    % Show solved reaction forces
    if solved && ~isempty(reaction_forces)
        if ~isempty(pin_joint) && pin_joint <= J
            px = joints(pin_joint,1); py = joints(pin_joint,2);
            text(hAx, px-1.5, py+1, ...
                sprintf('Rx=%.1f\nRy=%.1f', reaction_forces(1), reaction_forces(2)), ...
                'FontSize', 7, 'Color', [0 0.6 0], 'FontWeight', 'bold', ...
                'BackgroundColor', [0.9 1 0.9]);
        end
        if ~isempty(roller_joint) && roller_joint <= J
            rx2 = joints(roller_joint,1); ry2 = joints(roller_joint,2);
            text(hAx, rx2+1, ry2+1, ...
                sprintf('Ry=%.1f', reaction_forces(3)), ...
                'FontSize', 7, 'Color', [0 0.6 0], 'FontWeight', 'bold', ...
                'BackgroundColor', [0.9 1 0.9]);
        end
    end

    % Title bar — shows cost & max load after solving
    J_count = size(joints, 1);
    M_count_t = size(members, 1);
    M_need = max(2*J_count - 3, 0);

    if solved && ~isempty(W_max) && ~isempty(critical_member)
        tl = 0;
        for ti = 1:M_count_t
            tl = tl + norm(joints(members(ti,2),:) - joints(members(ti,1),:));
        end
        tc = CL * tl + CJ * J_count;
        title(hAx, sprintf(['[SOLVED]   Max Load: %.1f oz   |   ' ...
            'Cost: $%.0f   |   Load/Cost: %.4f oz/$   |   ' ...
            'Critical: m%d'], ...
            W_max, tc, W_max/tc, critical_member), ...
            'FontSize', 11, 'FontWeight', 'bold', 'Color', [0 0.5 0]);
    else
        title(hAx, sprintf('Mode: %s   J = %d   M = %d   (need M = %d)', ...
            upper(strrep(mode, '_', ' ')), J_count, M_count_t, M_need), ...
            'FontSize', 11, 'FontWeight', 'bold', 'Color', [0.1 0.1 0.5]);
    end

    set(hAx, 'XLim', xl, 'YLim', yl);
    hold(hAx, 'off');

    update_status();
end

% ----- UPDATE STATUS PANEL -----
function update_status()
    J = size(joints, 1);
    M_count = size(members, 1);
    M_needed = max(2*J - 3, 0);

    % Member lengths
    total_len = 0;
    for mi = 1:M_count
        total_len = total_len + norm(joints(members(mi,2),:) - joints(members(mi,1),:));
    end
    cost = CL * total_len + CJ * J;

    lines = {};
    lines{end+1} = sprintf('GEOMETRY');
    lines{end+1} = sprintf('  Joints:    J = %d', J);
    lines{end+1} = sprintf('  Members:   M = %d', M_count);
    if J >= 2
        lines{end+1} = sprintf('  Need M:    2J-3 = %d  %s', M_needed, ...
            iff(M_count == M_needed, 'OK', ['(' num2str(M_count - M_needed) ')']));
    end
    lines{end+1} = '';
    lines{end+1} = sprintf('COST');
    lines{end+1} = sprintf('  Total length: %.1f / %d in', total_len, MAX_TOTAL_LEN);
    lines{end+1} = sprintf('  Cost:  $%.0f', cost);
    lines{end+1} = '';

    % Span info
    if ~isempty(pin_joint) && ~isempty(roller_joint) ...
            && pin_joint <= J && roller_joint <= J
        span = abs(joints(roller_joint,1) - joints(pin_joint,1));
        lines{end+1} = sprintf('SPAN: %.1f in  [%d-%d]', span, MIN_SPAN, MAX_SPAN);
    end
    if ~isempty(pin_joint) && ~isempty(load_joint) ...
            && pin_joint <= J && load_joint <= J
        dx_pl = abs(joints(load_joint,1) - joints(pin_joint,1));
        dy_pl = joints(load_joint,2) - joints(pin_joint,2);
        lines{end+1} = sprintf('Load dx: %.1f in [%d-%d]', dx_pl, MIN_LOAD_DX, MAX_LOAD_DX);
        lines{end+1} = sprintf('Load dy: %.1f in [%d-%d]', dy_pl, MIN_LOAD_DY, MAX_LOAD_DY);
    end

    % Violations
    viols = validate_constraints();
    lines{end+1} = '';
    if isempty(viols)
        lines{end+1} = 'VIOLATIONS: None';
    else
        lines{end+1} = sprintf('VIOLATIONS: %d', length(viols));
        for vi = 1:length(viols)
            lines{end+1} = ['  ! ' viols{vi}];
        end
    end

    % Solved results
    if solved
        lines{end+1} = '';
        lines{end+1} = '--- SOLVED ---';
        lines{end+1} = sprintf('  Max Load:     %.1f oz', W_max);
        if ~isempty(W_max_low)
            lines{end+1} = sprintf('  Max Load Low: %.1f oz', W_max_low);
            lines{end+1} = sprintf('  Uncertainty:  +/- %.1f oz', W_max - W_max_low);
        end
        lines{end+1} = sprintf('  Critical:     m%d', critical_member);
        lines{end+1} = sprintf('  Load/Cost:    %.4f oz/$', W_max / cost);
        lines{end+1} = '';
        lines{end+1} = 'MEMBER FORCES:';
        for mi = 1:size(members,1)
            f = member_forces(mi);
            if f > 1e-6, tc = '(T)';
            elseif f < -1e-6, tc = '(C)';
            else, tc = '(0)'; end
            crit_str = '';
            if mi == critical_member, crit_str = ' <CRIT>'; end
            lines{end+1} = sprintf('  m%d: %.2f %s%s', mi, abs(f), tc, crit_str);
        end
        lines{end+1} = '';
        lines{end+1} = 'REACTIONS:';
        lines{end+1} = sprintf('  Sx1: %.2f', reaction_forces(1));
        lines{end+1} = sprintf('  Sy1: %.2f', reaction_forces(2));
        lines{end+1} = sprintf('  Sy2: %.2f', reaction_forces(3));
    end

    set(hStatusText, 'String', strjoin(lines, char(10)));
end

% ----- VALIDATE CONSTRAINTS -----
function viols = validate_constraints()
    viols = {};
    J = size(joints, 1);
    M_count = size(members, 1);

    % Member lengths
    for mi = 1:M_count
        L_m = norm(joints(members(mi,2),:) - joints(members(mi,1),:));
        if L_m < MIN_MEMBER_LEN - 0.01
            viols{end+1} = sprintf('m%d too short (%.1f")', mi, L_m);
        elseif L_m > MAX_MEMBER_LEN + 0.01
            viols{end+1} = sprintf('m%d too long (%.1f")', mi, L_m);
        end
    end

    % Span
    if ~isempty(pin_joint) && ~isempty(roller_joint) ...
            && pin_joint <= J && roller_joint <= J
        span = abs(joints(roller_joint,1) - joints(pin_joint,1));
        if span < MIN_SPAN - 0.01 || span > MAX_SPAN + 0.01
            viols{end+1} = sprintf('Span %.1f" not in [%d,%d]', span, MIN_SPAN, MAX_SPAN);
        end
    end

    % Load position
    if ~isempty(pin_joint) && ~isempty(load_joint) ...
            && pin_joint <= J && load_joint <= J
        dx_lp = abs(joints(load_joint,1) - joints(pin_joint,1));
        dy_lp = joints(load_joint,2) - joints(pin_joint,2);
        if dx_lp < MIN_LOAD_DX - 0.01 || dx_lp > MAX_LOAD_DX + 0.01
            viols{end+1} = sprintf('Load dx=%.1f" not in [%d,%d]', dx_lp, MIN_LOAD_DX, MAX_LOAD_DX);
        end
        if dy_lp < MIN_LOAD_DY - 0.01 || dy_lp > MAX_LOAD_DY + 0.01
            viols{end+1} = sprintf('Load dy=%.1f" not in [%d,%d]', dy_lp, MIN_LOAD_DY, MAX_LOAD_DY);
        end
    end

    % Joints below y=0
    for ji = 1:J
        if joints(ji,2) < -0.01
            viols{end+1} = sprintf('J%d below support line', ji);
        end
    end

    % No joints directly below load joint
    if ~isempty(load_joint) && load_joint <= J
        lx = joints(load_joint, 1);
        ly = joints(load_joint, 2);
        for ji = 1:J
            if ji ~= load_joint && abs(joints(ji,1) - lx) < 0.01 && joints(ji,2) < ly - 0.01
                viols{end+1} = sprintf('J%d directly below load joint', ji);
            end
        end
    end

    % Simple truss
    if J >= 3 && M_count ~= 2*J - 3
        viols{end+1} = sprintf('M=%d but need 2J-3=%d', M_count, 2*J-3);
    end

    % Total material
    total_len = 0;
    for mi = 1:M_count
        total_len = total_len + norm(joints(members(mi,2),:) - joints(members(mi,1),:));
    end
    if total_len > MAX_TOTAL_LEN + 0.01
        viols{end+1} = sprintf('Total length %.1f" > %d"', total_len, MAX_TOTAL_LEN);
    end

    % Member crossings
    for i = 1:M_count
        for j = i+1:M_count
            % Skip if they share a joint
            if any(members(i,:) == members(j,1)) || any(members(i,:) == members(j,2))
                continue;
            end
            p1 = joints(members(i,1),:); p2 = joints(members(i,2),:);
            p3 = joints(members(j,1),:); p4 = joints(members(j,2),:);
            if segments_intersect(p1, p2, p3, p4)
                viols{end+1} = sprintf('m%d and m%d cross', i, j);
            end
        end
    end
end

% ----- SEGMENT INTERSECTION TEST -----
function result = segments_intersect(p1, p2, p3, p4)
    d1 = p2 - p1; d2 = p4 - p3;
    cross_d = d1(1)*d2(2) - d1(2)*d2(1);
    if abs(cross_d) < 1e-10
        result = false; return;
    end
    d3 = p3 - p1;
    t = (d3(1)*d2(2) - d3(2)*d2(1)) / cross_d;
    u = (d3(1)*d1(2) - d3(2)*d1(1)) / cross_d;
    result = (t > 0.001 && t < 0.999 && u > 0.001 && u < 0.999);
end

% ----- SNAP TO GRID -----
function [sx, sy] = snap_to_grid(x, y)
    sx = round(x);
    sy = round(y);
end

% ----- FIND NEAREST JOINT -----
function idx = find_nearest_joint(x, y, radius)
    idx = [];
    if isempty(joints), return; end
    dists = sqrt((joints(:,1)-x).^2 + (joints(:,2)-y).^2);
    [mn, mi] = min(dists);
    if mn <= radius
        idx = mi;
    end
end

% ----- FIND NEAREST MEMBER -----
function idx = find_nearest_member(x, y, radius)
    idx = [];
    if isempty(members), return; end
    best_d = inf;
    for mi = 1:size(members,1)
        p = [x, y];
        a = joints(members(mi,1),:);
        b = joints(members(mi,2),:);
        ab = b - a; ap = p - a;
        t = dot(ap, ab) / dot(ab, ab);
        t = max(0, min(1, t));
        proj = a + t * ab;
        d = norm(p - proj);
        if d < best_d
            best_d = d;
            idx = mi;
        end
    end
    if best_d > radius
        idx = [];
    end
end

% ----- PUSH UNDO STATE -----
function push_undo()
    state.joints = joints;
    state.members = members;
    state.pin_joint = pin_joint;
    state.roller_joint = roller_joint;
    state.load_joint = load_joint;
    state.load_magnitude = load_magnitude;
    undo_stack{end+1} = state;
    if length(undo_stack) > 50
        undo_stack = undo_stack(end-49:end);
    end
end

% ----- UNDO -----
function cb_undo()
    if isempty(undo_stack), return; end
    state = undo_stack{end};
    undo_stack = undo_stack(1:end-1);
    joints = state.joints;
    members = state.members;
    pin_joint = state.pin_joint;
    roller_joint = state.roller_joint;
    load_joint = state.load_joint;
    load_magnitude = state.load_magnitude;
    solved = false; selected_joint = [];
    redraw();
end

% ----- CLEAR ALL -----
function cb_clear()
    answer = questdlg('Clear the entire truss?', 'Confirm Clear', 'Yes', 'No', 'No');
    if ~strcmp(answer, 'Yes'), return; end
    push_undo();
    joints = zeros(0,2); members = zeros(0,2);
    pin_joint = []; roller_joint = []; load_joint = [];
    solved = false; selected_joint = [];
    member_forces = []; reaction_forces = []; critical_member = [];
    redraw();
end

% ----- MODE BUTTON CALLBACK -----
function cb_mode_button(src, ~)
    mode = src.UserData;
    selected_joint = [];
    % Depress all others
    for bi = 1:length(mode_buttons)
        mode_buttons{bi}.Value = strcmp(mode_buttons{bi}.UserData, mode);
    end
    % Update label
    labels = struct('add_joint','ADD JOINT', 'add_member','ADD MEMBER', ...
        'set_pin','SET PIN', 'set_roller','SET ROLLER', 'set_load','SET LOAD', ...
        'move_joint','MOVE JOINT', 'delete','DELETE');
    set(hModeLabel, 'String', ['Mode: ' labels.(mode)]);
    redraw();
end

% ----- KEYBOARD SHORTCUTS -----
function cb_key_press(~, evt)
    ctrl = any(strcmp(evt.Modifier, 'control'));
    switch evt.Key
        case 'j', set_mode('add_joint');
        case 'm', set_mode('add_member');
        case 'p', set_mode('set_pin');
        case 'r', set_mode('set_roller');
        case 'l', set_mode('set_load');
        case 'v', set_mode('move_joint');
        case 'd', set_mode('delete');
        case 's', solve_truss();
        case 'e', cb_export();
        case 'z'
            if ctrl, cb_undo(); end
        case 'escape'
            selected_joint = [];
            set_mode('add_joint');
    end
end

function set_mode(new_mode)
    mode = new_mode;
    selected_joint = [];
    for bi = 1:length(mode_buttons)
        mode_buttons{bi}.Value = strcmp(mode_buttons{bi}.UserData, mode);
    end
    labels = struct('add_joint','ADD JOINT', 'add_member','ADD MEMBER', ...
        'set_pin','SET PIN', 'set_roller','SET ROLLER', 'set_load','SET LOAD', ...
        'move_joint','MOVE JOINT', 'delete','DELETE');
    set(hModeLabel, 'String', ['Mode: ' labels.(mode)]);
    redraw();
end

% ----- GET AXES COORDINATES FROM CLICK -----
function [ax, ay, in_axes] = get_axes_point()
    cp = get(hAx, 'CurrentPoint');
    ax = cp(1,1); ay = cp(1,2);
    xl = get(hAx, 'XLim'); yl = get(hAx, 'YLim');
    in_axes = ax >= xl(1) && ax <= xl(2) && ay >= yl(1) && ay <= yl(2);
end

% ----- MOUSE DOWN -----
function cb_mouse_down(~, ~)
    [cx, cy, in_ax] = get_axes_point();
    if ~in_ax, return; end

    switch mode
        case 'add_joint'
            [sx, sy] = snap_to_grid(cx, cy);
            % Check for existing joint at this location
            if ~isempty(find_nearest_joint(sx, sy, 0.4))
                return;
            end
            push_undo();
            joints(end+1, :) = [sx, sy];
            solved = false;
            redraw();

        case 'add_member'
            jj = find_nearest_joint(cx, cy, 1.5);
            if isempty(jj), return; end
            if isempty(selected_joint)
                selected_joint = jj;
                redraw();
            else
                if jj == selected_joint
                    selected_joint = [];
                    redraw();
                    return;
                end
                % Check for duplicate member
                pair = sort([selected_joint, jj]);
                for mi = 1:size(members,1)
                    if isequal(sort(members(mi,:)), pair)
                        selected_joint = [];
                        redraw();
                        return;
                    end
                end
                push_undo();
                members(end+1, :) = [selected_joint, jj];
                selected_joint = [];
                solved = false;
                redraw();
            end

        case 'set_pin'
            jj = find_nearest_joint(cx, cy, 1.5);
            if isempty(jj), return; end
            push_undo();
            if jj == roller_joint, roller_joint = []; end
            pin_joint = jj;
            solved = false;
            redraw();

        case 'set_roller'
            jj = find_nearest_joint(cx, cy, 1.5);
            if isempty(jj), return; end
            push_undo();
            if jj == pin_joint, pin_joint = []; end
            roller_joint = jj;
            solved = false;
            redraw();

        case 'set_load'
            jj = find_nearest_joint(cx, cy, 1.5);
            if isempty(jj), return; end
            answer = inputdlg('Load magnitude (oz, positive downward):', ...
                'Set Load', 1, {num2str(load_magnitude)});
            if isempty(answer), return; end
            val = str2double(answer{1});
            if isnan(val) || val <= 0, return; end
            push_undo();
            load_joint = jj;
            load_magnitude = val;
            solved = false;
            redraw();

        case 'move_joint'
            jj = find_nearest_joint(cx, cy, 1.5);
            if ~isempty(jj)
                push_undo();
                dragging_joint = jj;
                drag_active = true;
            end

        case 'delete'
            % Try joint first
            jj = find_nearest_joint(cx, cy, 1.5);
            if ~isempty(jj)
                push_undo();
                delete_joint(jj);
                solved = false;
                redraw();
                return;
            end
            % Try member
            mi = find_nearest_member(cx, cy, 0.8);
            if ~isempty(mi)
                push_undo();
                members(mi, :) = [];
                solved = false;
                redraw();
            end
    end
end

% ----- MOUSE MOVE -----
function cb_mouse_move(~, ~)
    [cx, cy, ~] = get_axes_point();

    if drag_active && ~isempty(dragging_joint)
        [sx, sy] = snap_to_grid(cx, cy);
        joints(dragging_joint, :) = [sx, sy];
        solved = false;
        redraw();
        return;
    end

    % Rubber-band line for add_member mode
    if strcmp(mode, 'add_member') && ~isempty(selected_joint) && selected_joint <= size(joints,1)
        % Delete old rubber band
        if ~isempty(hRubberBand) && isvalid(hRubberBand)
            delete(hRubberBand);
        end
        hold(hAx, 'on');
        sx = joints(selected_joint, 1); sy_j = joints(selected_joint, 2);
        hRubberBand = plot(hAx, [sx cx], [sy_j cy], '--', ...
            'Color', [0 0.7 0.7], 'LineWidth', 1.2);
        % Show tentative length
        tent_len = norm([cx-sx, cy-sy_j]);
        if tent_len > 0.5
            tmx = (sx+cx)/2; tmy = (sy_j+cy)/2;
            text(hAx, tmx, tmy+0.5, sprintf('%.1f"', tent_len), ...
                'FontSize', 8, 'Color', [0 0.6 0.6], 'Tag', 'rubbertext', ...
                'HorizontalAlignment', 'center');
        end
    end
end

% ----- MOUSE UP -----
function cb_mouse_up(~, ~)
    if drag_active
        drag_active = false;
        dragging_joint = [];
    end
end

% ----- DELETE JOINT (with cascading) -----
function delete_joint(idx)
    J = size(joints, 1);
    % Remove all members connected to this joint
    keep = true(size(members,1), 1);
    for mi = 1:size(members,1)
        if any(members(mi,:) == idx)
            keep(mi) = false;
        end
    end
    members = members(keep, :);

    % Decrement indices > idx
    members(members > idx) = members(members > idx) - 1;

    % Adjust support/load indices
    if ~isempty(pin_joint)
        if pin_joint == idx, pin_joint = [];
        elseif pin_joint > idx, pin_joint = pin_joint - 1; end
    end
    if ~isempty(roller_joint)
        if roller_joint == idx, roller_joint = [];
        elseif roller_joint > idx, roller_joint = roller_joint - 1; end
    end
    if ~isempty(load_joint)
        if load_joint == idx, load_joint = [];
        elseif load_joint > idx, load_joint = load_joint - 1; end
    end

    % Remove joint
    joints(idx, :) = [];
end

% ----- SOLVE TRUSS -----
function solve_truss()
    J = size(joints, 1);
    M_count = size(members, 1);

    % Pre-checks
    if J < 3
        errordlg('Need at least 3 joints to solve.', 'Cannot Solve'); return;
    end
    if isempty(pin_joint)
        errordlg('No pin support assigned.', 'Cannot Solve'); return;
    end
    if isempty(roller_joint)
        errordlg('No roller support assigned.', 'Cannot Solve'); return;
    end
    if isempty(load_joint)
        errordlg('No load assigned.', 'Cannot Solve'); return;
    end
    if M_count ~= 2*J - 3
        errordlg(sprintf('M=%d but need 2J-3=%d. Add/remove members.', M_count, 2*J-3), ...
            'Cannot Solve'); return;
    end

    % Build connection matrix C_mat (J x M)
    C_mat = zeros(J, M_count);
    for mi = 1:M_count
        C_mat(members(mi,1), mi) = 1;
        C_mat(members(mi,2), mi) = 1;
    end

    % Build Sx, Sy
    Sx = zeros(J, 3);
    Sy = zeros(J, 3);
    Sx(pin_joint, 1) = 1;
    Sy(pin_joint, 2) = 1;
    Sy(roller_joint, 3) = 1;

    % Build load vector
    Lvec = zeros(2*J, 1);
    Lvec(J + load_joint) = -load_magnitude;

    % Build equilibrium matrix A (2J x M+3)
    A = zeros(2*J, M_count + 3);
    X = joints(:,1)'; Y = joints(:,2)';

    for mi = 1:M_count
        jts = find(C_mat(:, mi));
        j1 = jts(1); j2 = jts(2);
        dx = X(j2) - X(j1);
        dy = Y(j2) - Y(j1);
        r = sqrt(dx^2 + dy^2);
        if r < 1e-10, continue; end

        A(j1, mi) = dx / r;
        A(j2, mi) = -dx / r;
        A(J + j1, mi) = dy / r;
        A(J + j2, mi) = -dy / r;
    end

    A(1:J, M_count+1:M_count+3) = Sx;
    A(J+1:2*J, M_count+1:M_count+3) = Sy;

    % Check rank
    if rank(A) < 2*J
        errordlg('Matrix A is singular. Check truss geometry (may be unstable).', ...
            'Cannot Solve'); return;
    end

    % Solve
    T_all = -A \ Lvec;
    member_forces = T_all(1:M_count);
    reaction_forces = T_all(M_count+1:M_count+3);

    % Buckling analysis
    mem_lens = zeros(M_count, 1);
    for mi = 1:M_count
        mem_lens(mi) = norm(joints(members(mi,2),:) - joints(members(mi,1),:));
    end
    member_lengths_solved = mem_lens;

    P_buckle     = C_BUCKLE * (L0 ./ mem_lens).^ALPHA;
    P_buckle_low = C_BUCKLE * (L0 ./ mem_lens).^ALPHA - U_FIT;

    R = member_forces / load_magnitude;

    W_fail     = inf(M_count, 1);
    W_fail_low = inf(M_count, 1);
    for mi = 1:M_count
        if R(mi) < -1e-10
            W_fail(mi)     = -P_buckle(mi) / R(mi);
            W_fail_low(mi) = -P_buckle_low(mi) / R(mi);
        end
    end

    [W_max, critical_member] = min(W_fail);
    [W_max_low, ~] = min(W_fail_low);

    solved = true;

    % Print formatted output to command window
    fprintf('\n========== TRUSS ANALYSIS RESULTS ==========\n');
    fprintf('Load: %.1f oz\n', load_magnitude);
    fprintf('Member forces in oz:\n');
    for mi = 1:M_count
        f = member_forces(mi);
        if f > 1e-6, tc = '(T)';
        elseif f < -1e-6, tc = '(C)';
        else, tc = '(0)'; end
        crit_str = ''; if mi == critical_member, crit_str = '  <-- CRITICAL'; end
        fprintf('  m%d: %.3f %s  [L=%.2f"]%s\n', mi, abs(f), tc, mem_lens(mi), crit_str);
    end
    fprintf('Reaction forces in oz:\n');
    fprintf('  Sx1: %.4f\n', reaction_forces(1));
    fprintf('  Sy1: %.4f\n', reaction_forces(2));
    fprintf('  Sy2: %.4f\n', reaction_forces(3));

    total_len = sum(mem_lens);
    cost = CL * total_len + CJ * J;
    fprintf('Cost: $%.0f\n', cost);
    fprintf('Max theoretical load: %.1f oz\n', W_max);
    fprintf('Max load (conservative): %.1f oz\n', W_max_low);
    fprintf('Load/Cost ratio: %.4f oz/$\n', W_max / cost);
    fprintf('=============================================\n\n');

    redraw();
end

% ----- EXPORT -----
function cb_export()
    J = size(joints, 1);
    M_count = size(members, 1);

    if J < 3 || M_count < 3
        errordlg('Build a truss first before exporting.', 'Cannot Export');
        return;
    end

    % Build matrices
    C_mat = zeros(J, M_count);
    for mi = 1:M_count
        C_mat(members(mi,1), mi) = 1;
        C_mat(members(mi,2), mi) = 1;
    end

    Sx_mat = zeros(J, 3);
    Sy_mat = zeros(J, 3);
    if ~isempty(pin_joint)
        Sx_mat(pin_joint, 1) = 1;
        Sy_mat(pin_joint, 2) = 1;
    end
    if ~isempty(roller_joint)
        Sy_mat(roller_joint, 3) = 1;
    end

    X_vec = joints(:,1)';
    Y_vec = joints(:,2)';

    L_vec = zeros(2*J, 1);
    if ~isempty(load_joint)
        L_vec(J + load_joint) = -load_magnitude;
    end

    % Save .mat file
    [fname, fpath] = uiputfile('*.mat', 'Save Truss Data', 'TrussDesign1.mat');
    if fname == 0, return; end
    filepath = fullfile(fpath, fname);

    C = C_mat; Sx = Sx_mat; Sy = Sy_mat; X = X_vec; Y = Y_vec; L = L_vec;
    save(filepath, 'C', 'Sx', 'Sy', 'X', 'Y', 'L');
    fprintf('Saved to %s\n', filepath);

    % Print paste-ready code block
    fprintf('\n%% --- Paste into truss_analysis.m Section 1 ---\n');
    fprintf('X = %s;\n', mat2str(X_vec));
    fprintf('Y = %s;\n', mat2str(Y_vec));
    fprintf('C = %s;\n', mat2str(C_mat));
    fprintf('pin_joint    = %d;\n', pin_joint);
    fprintf('roller_joint = %d;\n', roller_joint);
    fprintf('load_joint   = %d;\n', load_joint);
    fprintf('W            = %g;\n', load_magnitude);
    fprintf('%% --- End paste block ---\n\n');
end

% ----- HELPER: inline if -----
function r = iff(cond, a, b)
    if cond, r = a; else, r = b; end
end

end  % end truss_builder main function
