%% EK301 Truss Analysis Program
%  Solves for member forces, reaction forces, critical member,
%  maximum load, cost, and load/cost ratio for a 2D simple truss.
clear; clc; close all;

%% ========================================================================
%  SECTION 1: USER INPUTS — TRUSS DESIGNS
%  ========================================================================

% --- General Info (Applies to all tests) ---
group_info = '% EK301 Truss Design Project, Spring 2026.';
W          = 32;    % 32 oz downward load

% INSTRUCTIONS: Please highlight the block of the truss you want to test and 
% uncomment it (button at top of code section). Ensure all other designs
% are commented out or errors will occur


% -------------------------------------------------------------------------
%  TRUSS DESIGN SUBMISSIONS: TRUSS DESIGN 1
% -------------------------------------------------------------------------% --- Joint Locations (8 joints) ---
%  Joint:  1=J0    2=J1    3=J2    4=J3    5=J4    6=J5    7=J6    8=J7
X = [  0,     30,       8,     2,     8,     14,     20,     23  ];
Y = [  0,      0,       0,     6,     6,      6,      0,      6  ];

% --- Connection Matrix C (8 joints x 13 members) ---
%  Mapping: m1=J0-J3,  m2=J3-J2,  m3=J7-J1,  m4=J0-J2,  m5=J4-J2,
%           m6=J3-J4,  m7=J4-J5,  m8=J2-J5,  m9=J5-J6,  m10=J6-J7,
%           m11=J2-J6, m12=J5-J7 (critical), m13=J6-J1
C = [ 1  0  0  1  0  0  0  0  0  0  0  0  0;  % Joint 1 (J0)  — Pin
      0  0  1  0  0  0  0  0  0  0  0  0  1;  % Joint 2 (J1)  — Roller
      0  1  0  1  1  0  0  1  0  0  1  0  0;  % Joint 3 (J2)  — Load (W=32 oz)
      1  1  0  0  0  1  0  0  0  0  0  0  0;  % Joint 4 (J3)
      0  0  0  0  1  1  1  0  0  0  0  0  0;  % Joint 5 (J4)
      0  0  0  0  0  0  1  1  1  0  0  1  0;  % Joint 6 (J5)
      0  0  0  0  0  0  0  0  1  1  1  0  1;  % Joint 7 (J6)
      0  0  1  0  0  0  0  0  0  1  0  1  0]; % Joint 8 (J7)

% --- Support & Load Conditions ---
pin_joint    = 1;   % Joint 1 (J0) — pin support
roller_joint = 2;   % Joint 2 (J1) — roller support
load_joint   = 3;   % Joint 3 (J2) — load applied here (W = 32 oz, downward)


% -------------------------------------------------------------------------
%  TRUSS DESIGN SUBMISSIONS: TRUSS DESIGN 2
% -------------------------------------------------------------------------
% --- Joint Locations (8 joints) ---
% X = [0 30 12 20 5 25 17 11];
% Y = [0 0 0 0 5 6 7 7];
% 
% % --- Connection Matrix C (8 joints x 13 members) ---
% C = [1 0 0 0 0 0 1 0 0 0 0 0 0;
%      0 0 0 0 0 1 0 0 1 0 0 0 0;
%      0 1 1 0 0 0 1 1 0 0 1 0 0;
%      0 0 0 1 1 0 0 1 1 0 0 0 0;
%      1 1 0 0 0 0 0 0 0 0 0 1 0;
%      0 0 0 0 1 1 0 0 0 1 0 0 0;
%      0 0 1 1 0 0 0 0 0 1 0 0 1;
%      0 0 0 0 0 0 0 0 0 0 1 1 1];
% 
% % --- Support & Load Conditions ---
% pin_joint    = 1;   % Joint 1 — pin support
% roller_joint = 2;   % Joint 2 — roller support
% load_joint   = 3;   % Joint 3 — load applied here

% %% VERIFICATION TRUSSES
% % -------------------------------------------------------------------------
% %  VERIFICATION 1: EASY (3 Joints, 3 Members)
% % -------------------------------------------------------------------------
% % --- Joint Locations ---
% % Index:   1(J0)   2(J1)   3(J2)
% X = [  0,      15,     30  ];
% Y = [  0,      2,      0   ];
% 
% % --- Connection Matrix C ---
% C = [  1   0   1 ;   % 1 (J0)
%        1   1   0 ;   % 2 (J1)
%        0   1   1 ];  % 3 (J2)
% 
% % --- Support & Load Conditions ---
% pin_joint    = 1;   % J0 is pin
% roller_joint = 3;   % J2 is roller
% load_joint   = 2;   % J1 has the load


% -------------------------------------------------------------------------
%  VERIFICATION 2: MEDIUM (7 Joints, 11 Members) 
% -------------------------------------------------------------------------
% --- Joint Locations (7 joints) ---
%  Joint:  1=J0   2=J1   3=J2   4=J3   5=J4   6=J5   7=J6
% X = [  0,     26,    9,     17,    4.5,   11,    20   ];
% Y = [  0,      0,    0,      0,    5.5,    6,    5.5  ];
% 
% % --- Connection Matrix C (7 joints x 11 members) ---
% %  Mapping: m1=J0-J2, m2=J2-J3, m3=J3-J1, m4=J0-J4, m5=J4-J5, m6=J4-J2, 
% %           m7=J2-J5, m8=J5-J6, m9=J3-J6, m10=J5-J3, m11=J6-J1
% C = [ 1  0  0  1  0  0  0  0  0  0  0 ;  % 1 (J0)
%       0  0  1  0  0  0  0  0  0  0  1 ;  % 2 (J1)
%       1  1  0  0  0  1  1  0  0  0  0 ;  % 3 (J2)
%       0  1  1  0  0  0  0  0  1  1  0 ;  % 4 (J3)
%       0  0  0  1  1  1  0  0  0  0  0 ;  % 5 (J4)
%       0  0  0  0  1  0  1  1  0  1  0 ;  % 6 (J5)
%       0  0  0  0  0  0  0  1  1  0  1 ]; % 7 (J6)
% 
% % --- Support & Load Conditions ---
% pin_joint    = 1;   % Joint 1 (J0) is pin
% roller_joint = 2;   % Joint 2 (J1) is roller
% load_joint   = 3;   % Joint 3 (J2) has the load


% -------------------------------------------------------------------------
%  VERIFICATION 3: HARD (12 Joints, 21 Members)
% -------------------------------------------------------------------------
% % --- Joint Locations ---
% X = [  0,     30,    5,     10,    15,    20,    25,    5,     12.5,  22.5,  27.5,   17.5  ];
% Y = [  0,     0,     0,     1,     0,     0,     0,     8,     10.5,  9.5,   6.5,    8     ];
% 
% % --- Connection Matrix C ---
% C = [  1  0  0  0  0  0  1  0  0  0   0   0   0   0   0   0   0   0   0   0   0 ;  % 1 (J0)
%        0  0  0  0  0  1  0  0  0  0   0   0   0   0   1   0   0   0   0   0   0 ;  % 2 (J1)
%        1  1  0  0  0  0  0  1  0  0   0   0   0   0   0   0   0   0   0   0   0 ;  % 3 (J2)
%        0  1  1  0  0  0  0  0  1  1   0   0   0   0   0   0   0   0   0   0   0 ;  % 4 (J3)
%        0  0  1  1  0  0  0  0  0  0   0   1   0   0   0   0   0   0   1   0   0 ;  % 5 (J4)
%        0  0  0  1  1  0  0  0  0  0   0   0   1   0   0   0   0   0   0   0   1 ;  % 6 (J5)
%        0  0  0  0  1  1  0  0  0  0   0   0   0   0   0   1   1   0   0   0   0 ;  % 7 (J6)
%        0  0  0  0  0  0  1  1  1  0   1   0   0   0   0   0   0   0   0   0   0 ;  % 8 (J7)
%        0  0  0  0  0  0  0  0  0  1   1   1   0   0   0   0   0   1   0   0   0 ;  % 9 (J8)
%        0  0  0  0  0  0  0  0  0  0   0   0   1   1   0   0   1   0   0   1   0 ;  % 10(J9)
%        0  0  0  0  0  0  0  0  0  0   0   0   0   1   1   1   0   0   0   0   0 ;  % 11(J10)
%        0  0  0  0  0  0  0  0  0  0   0   0   0   0   0   0   0   1   1   1   1 ]; % 12(J11)
% 
% % --- Support & Load Conditions ---
% pin_joint    = 1;   % J0 is pin
% roller_joint = 2;   % J1 is roller
% load_joint   = 4;   % J3 has the load

%% ========================================================================
%  SECTION 2: DERIVED QUANTITIES & VALIDATION
%  ========================================================================

J = length(X);          % number of joints
M = size(C, 2);         % number of members

% Check simple truss condition: M = 2J - 3
if M ~= 2*J - 3
    error('Truss is not simple: M=%d but 2J-3=%d. Check your geometry.', M, 2*J-3);
end

% Check connection matrix columns each sum to 2
col_sums = sum(C, 1);
if any(col_sums ~= 2)
    bad = find(col_sums ~= 2);
    error('Connection matrix error: column(s) [%s] do not sum to 2.', num2str(bad));
end

% Build support connectivity matrices Sx and Sy (J x 3)
% Columns correspond to: [RPx, RPy, RRy]
Sx = zeros(J, 3);
Sy = zeros(J, 3);
Sx(pin_joint, 1) = 1;   % RPx acts at pin joint in x-direction
Sy(pin_joint, 2) = 1;   % RPy acts at pin joint in y-direction
Sy(roller_joint, 3) = 1; % RRy acts at roller joint in y-direction

% Build load vector L (2J x 1)
% First J entries = x-direction loads, last J entries = y-direction loads
L = zeros(2*J, 1);
L(J + load_joint) = -W;  % negative because load acts downward

%% ========================================================================
%  SECTION 3: BUILD EQUILIBRIUM MATRIX A (2J x M+3)
%  ========================================================================

A = zeros(2*J, M + 3);

% Fill member columns (1 to M)
for m = 1:M
    % Find the two joints connected by member m
    joints = find(C(:, m));
    j1 = joints(1);
    j2 = joints(2);

    % Compute member length
    dx = X(j2) - X(j1);
    dy = Y(j2) - Y(j1);
    r  = sqrt(dx^2 + dy^2);

    % x-equilibrium coefficients (rows 1 to J)
    A(j1, m) = dx / r;    % force direction from j1 toward j2
    A(j2, m) = -dx / r;   % force direction from j2 toward j1

    % y-equilibrium coefficients (rows J+1 to 2J)
    A(J + j1, m) = dy / r;
    A(J + j2, m) = -dy / r;
end

% Fill support reaction columns (M+1 to M+3)
A(1:J, M+1:M+3)     = Sx;   % x-equilibrium rows get Sx
A(J+1:2*J, M+1:M+3) = Sy;   % y-equilibrium rows get Sy

% Check that A is invertible
if rank(A) < 2*J
    error('Matrix A is rank-deficient (rank=%d, need %d). Check your truss definition.', rank(A), 2*J);
end

%% ========================================================================
%  SECTION 4: SOLVE FOR UNKNOWN FORCES
%  ========================================================================

T_all = -A \ L;   % solve A*T + L = 0  =>  T = -A\L

member_forces  = T_all(1:M);          % internal member tensions
reaction_forces = T_all(M+1:M+3);     % [RPx; RPy; RRy]

%% ========================================================================
%  SECTION 5: BUCKLING ANALYSIS & CRITICAL MEMBER
%  ========================================================================

% Buckling parameters (from lab manual)
C_buckle = 37.5;   % oz
L0       = 10;     % in (stated reference length)
alpha    = 2;
U_fit    = 10;     % oz (stated input for uncertainty)

% Compute member lengths
member_lengths = zeros(M, 1);
for m = 1:M
    joints = find(C(:, m));
    j1 = joints(1);
    j2 = joints(2);
    member_lengths(m) = sqrt((X(j2)-X(j1))^2 + (Y(j2)-Y(j1))^2);
end

% Buckling force for each member (only matters for compression)
P_buckle     = C_buckle * (L0 ./ member_lengths).^alpha;          % nominal
P_buckle_low = C_buckle * (L0 ./ member_lengths).^alpha - U_fit;  % lower bound

% Ratio coefficients: T_m = R_m * W
R = member_forces / W;

% Find critical member: for compression members (R < 0),
% compute W_failure = -P_buckle / R and find the minimum
W_failure = inf(M, 1);
W_failure_low = inf(M, 1);
for m = 1:M
    if R(m) < 0  % member is in compression
        W_failure(m)     = -P_buckle(m) / R(m);
        W_failure_low(m) = -P_buckle_low(m) / R(m);
    end
end

[W_max, critical_member] = min(W_failure);
[W_max_low, ~]           = min(W_failure_low);
W_uncertainty            = W_max - W_max_low;

%% ========================================================================
%  SECTION 6: COST CALCULATION
%  ========================================================================

CL = 1;    % cost per inch of member length
CJ = 10;   % cost per joint
total_length = sum(member_lengths);
truss_cost   = CL * total_length + CJ * J;
load_cost_ratio = W_max / truss_cost;


%% ========================================================================
%  SECTION 7: FORMATTED OUTPUT
%  ========================================================================

% Calculate member forces at the theoretical maximum load (Requirement e)
T_at_max = R * W_max;

fprintf('\n%s\n', group_info);

% % --- TEMPORARY CHECK FOR HAND CALCULATIONS ---
% fprintf('\n--- Forces at Test Load (W = %.1f oz) ---\n', W);
% for m = 1:M
%     if member_forces(m) > 1e-6
%         tc = 'T';
%     elseif member_forces(m) < -1e-6
%         tc = 'C';
%     else
%         tc = '0';
%     end
%     fprintf('m%d: %8.3f oz (%s)\n', m, abs(member_forces(m)), tc);
% end
% fprintf('-------------------------------------------\n');
% % ---------------------------------------------

% --- Print Member Details Table ---
fprintf('\n--- Member Details ---\n');
fprintf('%-8s | %-10s | %-12s | %-14s | %-14s | %-15s\n', ...
    'Member', 'Length(in)', 'State', 'Max Force(oz)', 'Buckling(oz)', 'Uncertainty(oz)');
fprintf(repmat('-', 1, 85)); % Prints a dividing line
fprintf('\n');

for m = 1:M
    % Determine Tension (T), Compression (C), or Zero-force
    if T_at_max(m) > 1e-6
        tc = 'Tension';
    elseif T_at_max(m) < -1e-6
        tc = 'Compression';
    else
        tc = 'Zero-Force';
    end
    
    % Handle Buckling data formatting (only applies to Compression)
    if strcmp(tc, 'Compression')
        buckling_uncertainty = P_buckle(m) - P_buckle_low(m); 
        buckle_str = sprintf('%.2f', P_buckle(m));
        unc_str = sprintf('%.2f', buckling_uncertainty);
    else
        buckle_str = '-';
        unc_str = '-';
    end
    
    % Print the row: Bold it if it is the critical member
    if m == critical_member
        fprintf('<strong>%-8s | %-10.2f | %-12s | %-14.3f | %-14s | %-15s</strong>\n', ...
            sprintf('m%d*', m), member_lengths(m), tc, abs(T_at_max(m)), buckle_str, unc_str);
    else
        fprintf('%-8s | %-10.2f | %-12s | %-14.3f | %-14s | %-15s\n', ...
            sprintf('m%d', m), member_lengths(m), tc, abs(T_at_max(m)), buckle_str, unc_str);
    end
end

% --- Print Truss Performance Summary ---
fprintf('\n--- Truss Performance Summary ---\n');
fprintf('Reaction forces at test load (W=%.1f oz):\n', W);
fprintf('  Sx1: %.4f oz\n', reaction_forces(1));
fprintf('  Sy1: %.4f oz\n', reaction_forces(2));
fprintf('  Sy2: %.4f oz\n', reaction_forces(3));

% (f) Identify critical member
fprintf('\n(f) Critical member: m%d (length = %.2f in)\n', critical_member, member_lengths(critical_member));

% 2. Maximum load and uncertainty
fprintf('2.  Theoretical max load: %.2f oz\n', W_max);
fprintf('    Max load uncertainty: +/- %.2f oz\n', W_uncertainty);

% 3. Truss cost and load-to-cost ratio
fprintf('3.  Cost of truss: $%.0f\n', truss_cost);
fprintf('    Theoretical max load/cost ratio: %.4f oz/$\n', load_cost_ratio);

fprintf('\nTotal member length: %.2f in\n', total_length);

%% ========================================================================
%  SECTION 8: EXPORT .mat FILE
%  ========================================================================

% 1. Find the exact folder where this .m script is currently saved
script_dir = fileparts(mfilename('fullpath'));

% 2. Create the exact file path (combining the folder and the file name)
filename = 'TrussDesign1.mat';
full_file_path = fullfile(script_dir, filename);

% 3. Save using the full path
save(full_file_path, 'C', 'Sx', 'Sy', 'X', 'Y', 'L');

% Print out exactly where it was saved so you can always find it
fprintf('\nInput file saved to:\n%s\n', full_file_path);

%% ========================================================================
%  SECTION 9: TRUSS VISUALIZATION
%  ========================================================================
%   
% only really used for testing purposes to assure correct
%   truss is ulitilzed and outputs are generally consistent
% Compute forces at max load for visualization
%% ========================================================================
T_at_max = R * W_max;

figure('Name', 'Truss Design', 'NumberTitle', 'off');
hold on; axis equal; grid on;
title('Truss Design — Blue=Tension, Red=Compression, Thick Red=Critical');
xlabel('x (in)'); ylabel('y (in)');

% Plot members
for m = 1:M
    joints = find(C(:, m));
    j1 = joints(1);
    j2 = joints(2);
    xpts = [X(j1), X(j2)];
    ypts = [Y(j1), Y(j2)];

    if m == critical_member
        plot(xpts, ypts, 'r-', 'LineWidth', 3);
    elseif member_forces(m) < 0
        plot(xpts, ypts, 'r-', 'LineWidth', 1.5);
    elseif member_forces(m) > 0
        plot(xpts, ypts, 'b-', 'LineWidth', 1.5);
    else
        plot(xpts, ypts, 'k-', 'LineWidth', 1);
    end

    % Label member at midpoint
    mx = (X(j1) + X(j2)) / 2;
    my = (Y(j1) + Y(j2)) / 2;
    text(mx, my, sprintf('m%d', m), 'FontSize', 8, 'Color', [0.3 0.3 0.3], ...
        'HorizontalAlignment', 'center', 'BackgroundColor', 'w');
end

% Plot joints
plot(X, Y, 'ko', 'MarkerSize', 8, 'MarkerFaceColor', 'k');
for j = 1:J
    text(X(j), Y(j) + 0.5, sprintf('J%d', j), 'FontSize', 9, 'FontWeight', 'bold', ...
        'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom');
end

% Mark supports
plot(X(pin_joint), Y(pin_joint), 'g^', 'MarkerSize', 14, 'MarkerFaceColor', 'g');
plot(X(roller_joint), Y(roller_joint), 'go', 'MarkerSize', 14, 'MarkerFaceColor', 'g');

% Mark load
quiver(X(load_joint), Y(load_joint), 0, -2, 'k', 'LineWidth', 2, 'MaxHeadSize', 0.8);
text(X(load_joint), Y(load_joint) - 2.5, sprintf('W=%.0f oz', W), ...
    'HorizontalAlignment', 'center', 'FontSize', 9);

hold off;
