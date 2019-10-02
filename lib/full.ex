defmodule Full do

  use GenServer



  def selected_neighbor(n) do
    :rand.uniform(n)
    |> node_name()
  end
  #
  def init([x,n, is_push_sum]) do
    case is_push_sum do
      0 -> {:ok, [Active,0,0, n, x ] } #[ rec_count, sent_count, n, self_number_id | neighbors ]
      1 -> {:ok, [Active,0, 0, 0, 0, x, 1, n, x] } #[ rec_count,streak,prev_s_w,to_terminate, s, w, n, self_number_id | neighbors ]
    end
  end

    #
  def handle_cast({:message_gossip, _received}, [status,count,sent,n,x ] =state ) do
    [i,j] = get_cordinates(n,x)
    case count < 100 do
      true ->  GenServer.cast(Master,{:received, [{i,j}]})
               gossip(x,self(),n,i,j)
      false -> GenServer.cast(Master,{:hibernated, [{i,j}]})
    end
    {:noreply,[status,count+1 ,sent,n, x  ]}
  end

  def gossip(x,pid, n,i,j) do
    the_one = selected_neighbor(n)
    case the_one == node_name(x) do
      true -> gossip(x,pid, n,i,j)
      false ->
        case GenServer.call(the_one,:is_active) do
          Active -> GenServer.cast(the_one, {:message_gossip, :_sending})
                    inactive_xy -> GenServer.cast(Master,{:neighbors_inactive, inactive_xy})
                    gossip(x,pid, n,i,j)
        end
      end
  end

      #
  def handle_cast({:message_push_sum, {rec_s, rec_w} }, [status,count,streak,prev_s_w,term, s ,w, n, x | neighbors ] = state ) do
    [i,j] = get_cordinates(n,x)
    GenServer.cast(Master,{:received, [{i,j}]})
      case abs(((s+rec_s)/(w+rec_w))-prev_s_w) < :math.pow(10,-10) do
        false ->push_sum(x,(s+rec_s)/2,(w+rec_w)/2,n,self(),i,j)
                {:noreply,[status,count+1, 0, (s+rec_s)/(w+rec_w), term, (s+rec_s)/2, (w+rec_w)/2, n, x  | neighbors]}
        true ->
          case streak + 1 == 3 do
            true ->  GenServer.cast(Master,{:hibernated, [{i,j}]})
                      {:noreply,[status,count+1, streak+1, (s+rec_s)/(w+rec_w), 1, (s+rec_s), (w+rec_w), n, x  | neighbors]}
            false -> push_sum(x,(s+rec_s)/2, (w+rec_w)/2, n, self(), i, j)
                      {:noreply,[status,count+1, streak+1, (s+rec_s)/(w+rec_w), 0, (s+rec_s)/2, (w+rec_w)/2, n, x  | neighbors]}
          end
      end
  end

 #
  def push_sum(x,s,w,n,pid ,i,j) do
    the_one = selected_neighbor(n)
    case the_one == node_name(x) do
      true -> push_sum(x,s,w,n,pid,i,j)
      false ->
        case GenServer.call(the_one,:is_active) do
          Active -> GenServer.cast(the_one,{:message_push_sum,{ s,w}})
          ina_xy -> GenServer.cast(Master,{:neighbors_inactive, ina_xy})
                    push_sum(x,s,w,n,pid ,i,j)
        end
      end
  end

  def handle_call(:is_active , _from, state) do
    {status,n,x} =
      case state do
        [status,_count,_streak,_prev_s_w,0, _s ,_w, n, x | _neighbors ] -> {status,n,x}
        [status,_count,_sent,n,x| _neighbors ] -> {status,n,x}
      end
    case status == Active do
      true -> {:reply, status, state }
      false ->
        [i,j] = get_cordinates(n, x)
        {:reply, [{i,j}], state }
    end
  end
  def get_cordinates(numberOfNodes,x) do
    length = round(Float.ceil(:math.sqrt(numberOfNodes)))
    i = rem(x-1,length) + 1
    j = round(Float.floor(((x-1)/length))) + 1
    [i,j]
  end

  def handle_cast({:goto_sleep, _},[ status |t ] ) do
    {:noreply,[ Inactive | t]}
  end
  def create_topology(n, is_push_sum \\ 0) do
    all_nodes =
      for x <- 1..n do
        name = node_name(x)
        GenServer.start_link(Full, [x,n,is_push_sum], name: name)
        name
      end
    GenServer.cast(Master,{:all_nodes_update,all_nodes})
  end

  def node_name(x) do
    a = x|> Integer.to_string |> String.pad_leading(7,"0")
    "Elixir.D"<>a
    |>String.to_atom
  end



end
