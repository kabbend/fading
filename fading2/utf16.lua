
utf16 = {}

  -- Constantes liees aux plages UTF-16
local lead_start = 0xD800
local tail_start = 0xDC00
local tail_end   = 0xDFFF
local bmp_end    = 0xFFFF
local max_cp     = 0x10FFFF
 
    -- Convertit deux mots de 16 bits (supposes encodes en UTF-16) en
    -- un codepoint Unicode. Le deuxieme mot est ignore le cas echeant.
    -- Renvoie -1 s'il y a un probleme d'encodage.  */
local function cp_from_UTF16(lead, tail)  
        if (lead < lead_start or lead > tail_end) then return lead 
        elseif (lead >= lead_start and lead < tail_start) then
            return (lead - 0xD800) * 0x400 + (tail - 0xDC00) + 0x10000;
        else 
            return -1;
    	end 
	end


    -- Convertit un codepoint Unicode en son encodage UTF-16 (un
    --  tableau de un ou deux entiers de 16 bits).
    --  Renvoie null si le codepoint est invalide.  */
local function cp_to_UTF16(codepoint) 
        if (codepoint >= 0 and codepoint < bmp_end)  then
            local pairs = { codepoint }
            return pairs
        elseif (codepoint > bmp_end and codepoint <= max_cp) then
            local pairs = { (codepoint - 0x10000) / 0x400 + 0xD800,
                            (codepoint - 0x10000) % 0x400 + 0XDC00 }
            return pairs
        else 
            return nil
	end
	end

    -- Constantes liees aux plages UTF-8
local utf8_cp1 = 0x80
local utf8_cp2 = 0x800
local utf8_cp3 = 0x10000
local utf8_cp4 = 0x200000
local utf8_bx = 0x80
local utf8_b2 = 0xC0
local utf8_b3 = 0xE0
local utf8_b4 = 0xF0
local utf8_b5 = 0xF8

    --/* Convertit un codepoint Unicode en son encodage UTF-8 (un
    --  tableau de un a quatre entiers de 8 bits).
    --  Renvoie null si le codepoint est invalide.  */
local function cp_to_UTF8(codepoint) 
        if (codepoint >= 0 and codepoint < utf8_cp1) then 
            local bytes = { codepoint }
            return bytes
        elseif (codepoint < utf8_cp2) then 
            local bytes = { codepoint / 0x40 + utf8_b2,
                      codepoint % 0x40 + utf8_bx }
            return bytes
        elseif (codepoint < utf8_cp3) then 
            local bytes = { codepoint / 0x40 / 0x40 + utf8_b3,
                      (codepoint / 0x40) % 0x40 + utf8_bx,
                      codepoint % 0x40 + utf8_bx }
            return bytes
        elseif (codepoint < utf8_cp4) then 
            local bytes = { codepoint / 0x40 / 0x40 / 0x40 + utf8_b4,
                      (codepoint / 0x40 / 0x40) % 0x40 + utf8_bx,
                      (codepoint / 0x40) % 0x40 + utf8_bx,
                      codepoint % 0x40 + utf8_bx };
            return bytes
        else
            return nil 
   	end
	end

   -- /* Convertit quatre mots de 8 bits (supposes encodes en UTF-8) en
   --   un codepoint Unicode. Les mots en plus sont ignores le cas
   --   echeant.  Renvoie -1 s'il y a un probleme d'encodage.  */
local function cp_from_UTF8(b1, b2, b3, b4) 
        if (b1 < utf8_bx) then
            return b1;
        elseif (b1 < utf8_b2) then
            return -1;
        elseif (b1 < utf8_b3 and 
                 b2 >= utf8_bx and b2 < utf8_b2) then
            return (b1 % 0x20)*0x40 + (b2 % 0x40);
        elseif (b1 < utf8_b4 and 
                 b2 >= utf8_bx and b2 < utf8_b2 and
                 b3 >= utf8_bx and b3 < utf8_b2) then
            return (b1 % 0x10)*0x40*0x40 + (b2 % 0x40)*0x40 + (b3 % 0x40);
        elseif (b1 < utf8_b5 and 
                 b2 >= utf8_bx and b2 < utf8_b2 and 
                 b3 >= utf8_bx and b3 < utf8_b2 and 
                 b4 >= utf8_bx and b4 < utf8_b2) then
            return (b1 % 0x8)*0x40*0x40*0x40 + (b2 % 0x40)*0x40*0x40 + (b3 % 0x40)*0x40 + (b4 % 0x40);
        else
            return -1;
   	end
	end

   -- /* Convertit un flux de UTF-8 a UTF-16 */
function utf16.utf8to16(sin)

        local b1 = string.byte(sin,1) 
        local b2 = string.byte(sin,2)
        local b3 = string.byte(sin,3)
        local b4
	local i = 4
	local out = ""
        while (b1) do 
            b4 = string.byte(sin,i)
	    i = i + 1
            local cp = cp_from_UTF8(b1, b2, b3, b4)
            if (cp) then 
        	local pairs = cp_to_UTF16(cp)
		if pairs then
        	 for j=1,#pairs do 
		    local c1 = (math.floor(pairs[j] / 0x100))
        	    if c1 ~= 0 then out = out .. string.char(math.floor(pairs[j] / 0x100)) end
        	    out = out .. string.char(pairs[j] % 0x100)
		 end
		end
            end 
            b1 = b2; b2 = b3; b3 = b4
	end	
	return out
	end 

    --[[
    --/* Convertit un flux de UTF-16 a UTF-8 */
function utf16.utf16to8(sin, sout) 
        throws IOException {
        int b1 = in.read(), 
            b2 = in.read(), 
            b3, b4;

        while (b1 != -1) {
            b3 = in.read();
            b4 = in.read();
            int cp = cp_from_UTF16(b1 * 0x100 + b2, b3 * 0x100 + b4);
            if (cp != -1) {
        	int[] bytes = cp_to_UTF8(cp);
        	for (int i = 0 ; i < bytes.length ; i++)
        	    out.write(bytes[i]);
            }
            b1 = b3; b2 = b4;
        }
    }

  --]]
  --

return utf16

